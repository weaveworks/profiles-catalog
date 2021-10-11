package test

import (
	"flag"
	"fmt"
	"io/ioutil"
	corev1 "k8s.io/api/core/v1"
	"log"
	"os"
	"strings"
	"testing"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/gruntwork-io/terratest/modules/k8s"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type myData struct {
	Profiles []Profile `yaml:"profiles,flow"`
}

type Profile struct {
	Name      string `yaml:"name"`
	Namespace string `yaml:"namespace"`
	//	Healthprobepath string `yaml:"healthprobepath"`
	//	Port            int    `yaml:"port"`
}

var kubeconfigpath = flag.String("kubeconfig", "../.conf/testing.kubeconfig", "kubeconfig path")
var valuespath = flag.String("values", "values.yaml", "profiles values.yaml path")
var uniqueprofilename = flag.String("profilename", "", "individual profile name")
var uniqueprofilenamespace = flag.String("profilenamespace", "", "individual profile namespace")

func TestProfiles(t *testing.T) {
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
	}else{
		tocheck = 1 
		profilesToCheck[profilenamespace] = append(profilesToCheck[profilenamespace], profilename)

	}

	checked := checkRunningProfiles(t, pods, kubeconfig, profilesToCheck, options)
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

func checkRunningProfiles(t *testing.T, pods []corev1.Pod, kubeconfig string, profilesToCheck map[string][]string, options *k8s.KubectlOptions) (checked int) {
	var namespace string
	checked = 0

	for i := 0; i < len(pods); i++ {
		namespace = pods[i].Namespace
		// waituntilavailavle needs specific namespace
		options = k8s.NewKubectlOptions("", kubeconfig, namespace)
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
