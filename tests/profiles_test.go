package test

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"testing"
	"time"
	"errors"

	"gopkg.in/yaml.v3"
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
var valuespath = flag.String("values", "values.yaml", "profiles values.yaml path")
var uniqueprofilename = flag.String("profilename", "", "individual profile name")
var uniqueprofilenamespace = flag.String("profilenamespace", "", "individual profile namespace")

func TestProfileInstallation(t *testing.T) {
	kubeconfig := *kubeconfigpath
	profiletocheck := *uniqueprofilename
	config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)
	clientset, _ := kubernetes.NewForConfig(config)
	var profiles ProfileInstallationList
	err := getProfileInstallations(clientset, &profiles)
	if err != nil {
		panic(err.Error())
	}
	err = checkInstalledProfiles(profiles, profiletocheck)
	if err != nil {
		t.Errorf("Profile '%s' not found on default namespace", profiletocheck)
	}
}

func checkInstalledProfiles(profiles ProfileInstallationList, profilename string) (error){
	for i := 0; i < len(profiles.Items); i++ {
		if profiles.Items[i].Name == profilename {
			return nil;
		}
	}
	return errors.New("Profile not installed");
}

func TestProfilesPods(t *testing.T) {
	t.Parallel()

	kubeconfig := *kubeconfigpath
	values := *valuespath
	profilename := *uniqueprofilename
	profilenamespace := *uniqueprofilenamespace
	config, err := readConf(values)
	profilesToCheck := make(map[string][]string)
	tocheck := 0

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

// append deployment, replicaset and daemonset with Label["helm.toolkit.fluxcd.io/name"] == profilename
// https://github.com/gruntwork-io/terratest/blob/master/modules/k8s/daemonset.go
// https://github.com/gruntwork-io/terratest/blob/master/modules/k8s/replicaset.go



func checkRunningPods(t *testing.T, pods []corev1.Pod, kubeconfig string, profilesToCheck map[string][]string, options *k8s.KubectlOptions) (checked int) {
	var namespace string
	//var a string
	checked = 0

	for i := 0; i < len(pods); i++ {
		namespace = pods[i].Namespace
		// waituntilavailable needs specific namespace
		options = k8s.NewKubectlOptions("", kubeconfig, namespace)
		//a=pods[i].Labels["kustomize.toolkit.fluxcd.io/name"]
		//fmt.Println(a)
		for k := 0; k < len(profilesToCheck[namespace]); k++ {
			if strings.Contains(pods[i].Name, profilesToCheck[namespace][k]) {
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