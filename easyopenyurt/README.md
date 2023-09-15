# Quick set-up OpenYurt

## 1. Introduction

This program extends [EasyOpenyurt](https://github.com/flyinghorse0510/easy_openyurt) to automate the set up process of an OpenYurt cluster. 

It support seting up a Kubernetes cluster using kubeadm and then deploy OpenYurt on it.

## 2. Brief overview

**Pre-Requsites of nodes:**
1. Ensure that SSH authentication is possible from local device to all nodes.
2. Ensure that every node have Golang(version at least 1.20) installed as script will build easy_openyurt from source.

**Components:**

|      Files      | Purpose  |
| :----------: | :---: |
| script.sh | <ul><li>Set up Kubernetes Cluster</li><li>Deploy OpenYurt on Kubernetes Cluster</li><li>Deploy Knative with easy_openyurt</li></ul> |
| master.sh | Set up Kubernetes Cluster - master node |
| worker.sh | Set up Kubernetes Cluster - worker node |

**Description**

1. Builds easy_openyurt from source.
2. Configure Master Node.
3. Generates and copy to local masterKey.yaml including information to set up worker node.
4. Configure Worker Node to from cluster with Master.
5. Deploy OpenYurt on Master and Worker Node.
6. (Optional) Deploy Knative (vHive stock-only mode compatible)

## 3. Usage

### 3.1 Preparations 
1. Download quickDeploy folder containing the 3 scripts.
2. Create text file(eg: workers.txt) containing `<remote_username>`@`<IPorHost>` for SSH to worker nodes.
```plaintext
john @ 192.168.1.100
mary @ example.com
jane @ 192.168.1.200

```

### 3.2 Run Script

```bash
./script.sh <remote_username>@<IPorHost> workers.txt

# arg1: master node IP/Host address
# arg2: text file containing worker nodes
```


## 4. Testing: Create NodePool and deploy apps
**Referenced from [EasyOpenyurt](https://github.com/flyinghorse0510/easy_openyurt)*

Here we use a docker image named ```lrq619/srcnn``` as our example.

Below instructions should all be executed on master node.

### 4.1 Create NodePool
Create file called cloud.yaml
```yaml
apiVersion: apps.openyurt.io/v1alpha1
kind: NodePool
metadata:
  name: beijing # can change to your own name
spec:
  type: Cloud
```
Create file called edge.yaml
```yaml
apiVersion: apps.openyurt.io/v1alpha1
kind: NodePool
metadata:
  name: hangzhou # can change to your own name
spec:
  type: Edge
  annotations:
    apps.openyurt.io/example: test-hangzhou
  labels:
    apps.openyurt.io/example: test-hangzhou
  taints:
  - key: apps.openyurt.io/example
    value: test-hangzhou
    effect: NoSchedule
```
run
```bash
kubectl apply -f cloud.yaml
kubectl apply -f edge.yaml
kubectl get np
```
the output should be similar to 
```bash
NAME       TYPE    READYNODES   NOTREADYNODES   AGE
beijing    Cloud   1            0               67m
hangzhou   Edge    1            0               66m
```

### 4.2 Create YurtAppSet
Create a file yurtset.yaml
```yaml
# Used to create YurtAppSet
apiVersion: apps.openyurt.io/v1alpha1
kind: YurtAppSet
metadata:
  labels:
    controller-tools.k8s.io: "1.0"
  name: yas-test
spec:
  selector:
    matchLabels:
      app: yas-test
  workloadTemplate:
    deploymentTemplate:
      metadata:
        labels:
          app: yas-test
      spec:
        template:
          metadata:
            labels:
              app: yas-test
          spec:
            containers: # can be changed to your own images
              - name: srcnn
                image: lrq619/srcnn
                ports:
                - containerPort: 8000 # the port docker exposes
  topology:
    pools:
    - name: beijing # cloud nodepool name
      nodeSelectorTerm:
        matchExpressions:
        - key: apps.openyurt.io/nodepool
          operator: In
          values:
          - beijing
      replicas: 1
    - name: hangzhou # edge nodepool name
      nodeSelectorTerm:
        matchExpressions:
        - key: apps.openyurt.io/nodepool
          operator: In
          values:
          - hangzhou
      replicas: 1
      tolerations:
      - effect: NoSchedule
        key: apps.openyurt.io/example
        operator: Exists
  revisionHistoryLimit: 5
```
Then run
```bash
kubectl apply -f yurtset.yaml
```
The deployments is automatically created.
You can check them by
```bash
kubectl get deploy
```
It should output something like
```bash
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
yas-test-beijing-6bv5g    1/1     1            1           59m
yas-test-hangzhou-z22r4   1/1     1            1           59m
```
### 4.3 Expose deployments to external ip(Optional)
If the master node is running on a node with public ip address you can choose the expose the deployments to that address by:
```bash
kubectl expose deployment <deploy-name>  --type=LoadBalancer --target-port <container-exposed-ip> --external-ip <ip>
```
For example:
```bash
kubectl expose deployment yas-test-beijing-6bv5g  --type=LoadBalancer --target-port 8000 --external-ip 128.110.217.71
```
Then you can use
```bash
kubectl get services
```
to check the services' public ip addresses and ports to access them.
To delete a service, use 
```
kubectl delete svc <service-name>
```