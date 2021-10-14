package test

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"gopkg.in/yaml.v3"
	v1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/k8s"
	Profiles "github.com/weaveworks/profiles/api/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

type ProfileInstallationList = Profiles.ProfileInstallationList

type myData struct {
	Profiles []Profile `yaml:"profiles,flow"`
}

type Profile struct {
	Name      string `yaml:"name"`
	Namespace string `yaml:"namespace"`
}

var kubeconfigpath = flag.String("kubeconfig", "../.conf/testing.kubeconfig", "kubeconfig path")
var valuespath = flag.String("values", "", "profiles values.yaml path")
var uniqueprofilename = flag.String("profilename", "", "individual profile name")
var uniqueprofilenamespace = flag.String("profilenamespace", "", "individual profile namespace")

func TestProfileInstallation(t *testing.T) {
	kubeconfig := *kubeconfigpath
	profiletocheck := *uniqueprofilename
	config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)
	clientset, _ := kubernetes.NewForConfig(config)
	var profiles ProfileInstallationList
	var err error
	var start time.Time
	for start = time.Now(); time.Since(start) < 600*time.Second && checkInstalledProfiles(profiles, profiletocheck) != nil; {
		err = getProfileInstallations(clientset, &profiles)
		if err != nil {
			panic(err.Error())
		}
		time.Sleep(1 * time.Second)
	}
	err = checkInstalledProfiles(profiles, profiletocheck)
	if err != nil {
		t.Errorf("Profile '%s' not found on default namespace after %s", profiletocheck, time.Since(start))
	}
	// wait for deployment, statefulset and daemonset to start 
	time.Sleep(30 * time.Second)
}

func TestProfileInstallationComponents(t *testing.T) {
	t.Parallel()

	kubeconfig := *kubeconfigpath
	config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)
	clientset, _ := kubernetes.NewForConfig(config)
	profilename := *uniqueprofilename
	checked := 0
	tocheck := 0
	profilesComponentsToCheck := make(map[string][]string)

	// Setup the kubectl config and context.
	options := k8s.NewKubectlOptions("", kubeconfig, "")

	// get list of pods
	pods := k8s.ListPods(t, options, metav1.ListOptions{})
	daemonSets := k8s.ListDaemonSets(t, options, metav1.ListOptions{})
	replicaSets := k8s.ListReplicaSets(t, options, metav1.ListOptions{})
	deploymentsList, _ := clientset.AppsV1().Deployments("").List(context.TODO(), metav1.ListOptions{})
	deployments := deploymentsList.Items
	statefulSetsList, _ := clientset.AppsV1().StatefulSets("").List(context.TODO(), metav1.ListOptions{})
	statefulSets := statefulSetsList.Items
	tocheck = tocheck + statefulsetToCheck(statefulSets, profilename, profilesComponentsToCheck)
	tocheck = tocheck + replicasetToCheck(deployments, replicaSets, profilename, profilesComponentsToCheck)
	tocheck = tocheck + daemonsetToCheck(daemonSets, profilename, profilesComponentsToCheck)

	checked = checkRunningPods(t, pods, kubeconfig, profilesComponentsToCheck, options)
	if tocheck != checked {
		t.Errorf("expected '%d' but got '%d'", tocheck, checked)
	}
}

func TestProfilesPods(t *testing.T) {
	t.Parallel()
	values := *valuespath

	kubeconfig := *kubeconfigpath
	profilename := *uniqueprofilename
	profilenamespace := *uniqueprofilenamespace
	config, err := readConf(values)
	profilesToCheck := make(map[string][]string)
	tocheck := 0

	if values == "" {
		t.Skip()
	}

	if err != nil {
		log.Fatal(err)
	}

	// Setup the kubectl config and context.
	options := k8s.NewKubectlOptions("", kubeconfig, "")

	// get list of pods
	pods := k8s.ListPods(t, options, metav1.ListOptions{})

	if profilename == "" || profilenamespace == "" {
		tocheck = mapProfilesFromConfig(config, kubeconfig, profilesToCheck, options)
		if tocheck == 0 {
			log.Println("no profiles to check")
			t.Skip()
			os.Exit(0)
		}
	} else {
		tocheck = 1
		profilesToCheck[profilenamespace] = append(profilesToCheck[profilenamespace], profilename)

	}

	checked := checkRunningPods(t, pods, kubeconfig, profilesToCheck, options)
	// ensure all profiles where tested
	if tocheck != checked {
		t.Errorf("expected '%d' but got '%d'", tocheck, checked)
	}
}

func mapProfilesFromConfig(config *myData, kubeconfig string, profilesToCheck map[string][]string, options *k8s.KubectlOptions) (tocheck int) {
	var name string
	var namespace string
	tocheck = 0

	for i := 0; i < len(config.Profiles); i++ {
		name = config.Profiles[i].Name
		namespace = config.Profiles[i].Namespace
		options = k8s.NewKubectlOptions("", kubeconfig, namespace)
		profilesToCheck[namespace] = append(profilesToCheck[namespace], name)
		tocheck++
	}
	return tocheck
}

func checkRunningPods(t *testing.T, pods []corev1.Pod, kubeconfig string, profilesToCheck map[string][]string, options *k8s.KubectlOptions) (checked int) {
	var namespace string
	var parentReference string
	checked = 0

	for i := 0; i < len(pods); i++ {
		namespace = pods[i].Namespace
		// waituntilavailable needs specific namespace
		options = k8s.NewKubectlOptions("", kubeconfig, namespace)
		for k := 0; k < len(profilesToCheck[namespace]); k++ {
			parentReference = pods[i].GetOwnerReferences()[0].Name
			if strings.Contains(parentReference, profilesToCheck[namespace][k]) {
				fmt.Println("Tested profile:", profilesToCheck[namespace][k], "Namespace: ", namespace, "Pod:", pods[i].Name)
				//wait until they are available
				k8s.WaitUntilPodAvailable(t, options, pods[i].Name, 60, 1*time.Second)
				checked++
			}
		}
	}
	return checked
}

func readConf(filename string) (*myData, error) {
	buf, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	c := &myData{}
	err = yaml.Unmarshal(buf, c)
	if err != nil {
		return nil, fmt.Errorf("in file %q: %v", filename, err)
	}

	return c, nil
}

func getProfileInstallations(clientset *kubernetes.Clientset, profiles *ProfileInstallationList) error {
	data, err := clientset.RESTClient().Get().AbsPath("/apis/weave.works/v1alpha1/").Namespace("default").Resource("profileinstallations").DoRaw(context.TODO())
	if err != nil {
		return err
	}
	err = json.Unmarshal(data, &profiles)
	return err
}

func checkInstalledProfiles(profiles ProfileInstallationList, profilename string) error {
	for i := 0; i < len(profiles.Items); i++ {
		if profiles.Items[i].Name == profilename {
			return nil
		}
	}
	return errors.New("Profile not installed")
}

func statefulsetToCheck(resource []v1.StatefulSet, profilename string, resourcesToCheck map[string][]string) (tocheck int) {
	var name string
	var namespace string
	var label string
	tocheck = 0
	for i := 0; i < len(resource); i++ {
		name = resource[i].Name
		namespace = resource[i].Namespace
		label = resource[i].Labels["helm.toolkit.fluxcd.io/name"]
		if strings.Contains(label, profilename) {
			resourcesToCheck[namespace] = append(resourcesToCheck[namespace], name)
			tocheck = tocheck + int(*resource[i].Spec.Replicas)
		}
	}
	return tocheck
}

func daemonsetToCheck(resource []v1.DaemonSet, profilename string, resourcesToCheck map[string][]string) (tocheck int) {
	var name string
	var namespace string
	var label string
	tocheck = 0

	for i := 0; i < len(resource); i++ {
		name = resource[i].Name
		namespace = resource[i].Namespace
		label = resource[i].Labels["helm.toolkit.fluxcd.io/name"]
		if strings.Contains(label, profilename) {
			resourcesToCheck[namespace] = append(resourcesToCheck[namespace], name)
			tocheck = tocheck + int(resource[i].Status.DesiredNumberScheduled)
		}
	}
	return tocheck

}

func replicasetToCheck(deployments []v1.Deployment, resource []v1.ReplicaSet, profilename string, resourcesToCheck map[string][]string) (tocheck int) {
	var name string
	var namespace string
	var label string
	var tempcheck []v1.Deployment
	var replicasetParentReference string
	tocheck = 0

	for i := 0; i < len(deployments); i++ {
		name = deployments[i].Name
		namespace = deployments[i].Namespace
		label = deployments[i].Labels["helm.toolkit.fluxcd.io/name"]
		if strings.Contains(label, profilename) {
			tempcheck = append(tempcheck, deployments[i])
		}
	}
	for i := 0; i < len(resource); i++ {
		name = resource[i].Name
		namespace = resource[i].Namespace
		label = resource[i].Labels["helm.toolkit.fluxcd.io/name"]
		for j := 0; j < len(tempcheck); j++ {
			replicasetParentReference = resource[i].GetOwnerReferences()[0].Name
			if tempcheck[j].Name == replicasetParentReference {
				resourcesToCheck[namespace] = append(resourcesToCheck[namespace], name)
				desiredReplicas, err := strconv.Atoi(resource[i].Annotations["deployment.kubernetes.io/desired-replicas"])
				if err != nil {
					fmt.Println(err)
					desiredReplicas = 1
				}
				tocheck = tocheck + int(desiredReplicas)
			}
		}
	}
	return tocheck

}
