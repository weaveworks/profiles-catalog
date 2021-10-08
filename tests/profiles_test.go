package test

import (
	"fmt"
	"io/ioutil"
	"log"
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

func TestProfiles(t *testing.T) {
	t.Parallel()

	var name string
	var namespace string

	profilesToCheck := make(map[string][]string)
	tocheck := 0
	checked := 0
	kubeconfig := "../.conf/testing.kubeconfig"

	config, err := readConf("values.yaml")
	if err != nil {
		log.Fatal(err)
	}

	// Setup the kubectl config and context.
	options := k8s.NewKubectlOptions("", kubeconfig, "")

	// get list of pods
	pods := k8s.ListPods(t, options, metav1.ListOptions{})

	for i := 0; i < len(config.Profiles); i++ {
		name = config.Profiles[i].Name
		namespace = config.Profiles[i].Namespace
		options = k8s.NewKubectlOptions("", kubeconfig, namespace)
		profilesToCheck[namespace] = append(profilesToCheck[namespace], name)
		tocheck++
	}

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
	// ensure all profiles where tested
	if tocheck != checked {
		t.Errorf("expected '%d' but got '%d'", tocheck, checked)
	}

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
