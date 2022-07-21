# NIS251: Building security defenses for edge computing devices Instructions

Author: emirayar@amazon.lu v1.0 20/07/2022

## Goals

- Detect a Malware threat on industrial edge computing use case
- Detect a Cryptocurrency mining threat on ML at the edge with computer vision use case

## Path

### Use Case-1
- Create a fleet of simulated AWS IoT Greengrass devices on a single AWS Cloud9 instance
- Deploy AWS Greengrass Device Defender component to simulated device fleet
- Create a security profile for the expected behaviour of the device
- Create an email alert using SNS notification feature in AWS IoT Device Defender for the security profile
- Choose one of the devices to simulate a malware running device condition and run the script
-  See the email alert and resolve the issue manually.

### Use Case-2
**NOTE:** Uses cases are linked with them and reuse the existing resources to save time. Attendees need to run Use Case #1 first to be able to proceed with Use Case #2
- Define custom metrics for devices' GPUs on AWS IoT Device Defender console
- Create a Quarantine device group to be used for an automated action to move infected devices into
- Create a AWS Lambda function that performs the custom automated action: moving the device to the Quarantine device group
- Create a new security profile for the expected behaviour of the device with custom GPU metrics.
- Create a trigger for the AWS Lambda function to be invoked by the SNS notification originated from Device Defender.
- Choose one of the devices to simulate a cryptocurrency mining running device condition and run the script
- See the email alert
- Confirm that device is moved to quarantine device group.

## Instructions

### 1. Prepare the environment

- Go to AWS Cloud9 console (https://us-east-1.console.aws.amazon.com/cloud9/home/create) and create a new Cloud9 instance with following parameters:
	- Instance type "t3.small (2 GiB RAM + 2 vCPU)" 
	- Platform: "Amazon Linux 2"
- Once the Cloud9 instance is ready, download the NIS251 Builders' Session artifacts repo:
```
cd ~/environment
git clone https://github.com/eercanayar/nis251-builders-session
```

- Run the following to download the resizer script and expand the storage of Cloud9 instance to 120GB
```
~/environment/nis251-builders-session
chmod +x resize.sh
./resize.sh 120
```

- Install required tools and packages:
```
# greengrass gdk
python3 -m pip install -U git+https://github.com/aws-greengrass/aws-greengrass-gdk-cli.git@v1.1.0
# docker-compose
pip3 install docker-compose
```

- Go to AWS IAM console, create an IAM user with 
	- username `gg_provisioning` 
	- AWS access type: only Access key - Programmatic access
	- Policy: `AdministratorAccess`
	
Get the `Access key ID` and `Secret access key` to place them into `nis251-builders-session/ggv2-provisioning-credentials/credentials` file and update your `region`. You'll delete this user and the `credentials` file after the provisioning done, because Greengrass uses certificates to authenticate itself.

Now, we have our development environment ready!

### 2. Create custom Greengrass component for AWS IoT Device Defender
We use a slightly modified version of public (and open source) AWS IoT Device Defender component for AWS IoT Greengrass. Those modifications are the following:

- Enhanced debugging/logging for a smooth Builders's Session
- Custom metrics from GPU (simulated) for the Use case #2

Public AWS IoT Device Defender component is deployed from the central AWS Greengrass component repository, but the modified version will be stored on your own account. 

Download and unzip the modified component source code:
```
mkdir ~/environment/ggv2-components
cd ~/environment/ggv2-components
wget https://d2u1t255uj9pta.cloudfront.net/reinforce/artifacts/com.awsreinforce.DeviceDefenderCustom.zip
unzip com.awsreinforce.DeviceDefenderCustom.zip
rm com.awsreinforce.DeviceDefenderCustom.zip
cd com.awsreinforce.DeviceDefenderCustom
```

Run the following to build and publish it:
```
gdk component build
gdk component publish
```

Go to AWS IoT Greengrass console > Components to confirm your component is published. 

Check the **Cheat Sheet** section if you want to make a modification in the component source code and deploy your updates.

### 3. Build and run Greengrass simulated device fleet

```
cd ~/environment/nis251-builders-session
# Build the container
docker build -t ggv2-nis251-image .
# Create greengrass containers
docker-compose up --no-start
# Start the first container only
docker start nis251-builders-session_nis251-gtw-01_1
```

- Now you have one simulated Greengrass devices running on your Cloud9 instance.
- It may take some time for it's deployment and appearing on the Greengrass console.
- You can run `docker ps` to check container statues.
- You can run `docker logs CONTAINER_ID` to check the container's logs to see if everyting is fine.
- You can go to _AWS IoT Greengrass console > Core devices_ section to see the created Greengrass device.
- Once your first Greengrass devices are up and running, you can run the following to start all of them:
    ```
    docker-compose start
    ```
- Then, you can go to _AWS IoT Greengrass console > Core devices_ section to see your all created Greengrass devices.


Once your all Greengrass devices are up and running, delete `nis251-builders-session/ggv2-provisioning-credentials/credentials` file and the IAM user you've created at the beginning of the session.

Also, run the following to allow each core device to download the component artifacts from S3.
```
echo "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\"],\"Resource\":\"arn:aws:s3:::awsreinforce-ggv2*\\/*\"}]}" > component-artifact-policy.json
aws iam put-role-policy --role-name GGV2TokenExchangeRole --policy-name GGV2ComponentArtifactPolicy --policy-document file://component-artifact-policy.json
```

### 4. Deploy components to the Greengrass simulated device fleet
Now it's time to deploy some components to your newly created devices, including the custom/modified AWS IoT Device Defender component. All the devices are added into _nis251-gtw_ thing group. So, you'll create a deployment that targeted to the _nis251-gtw_ thing group. Thus; all the devices under this thing group will receive the deploylement.

- Go to _AWS IoT Greengrass console > Deployments_
- Click create, specify a deployment name
- Choose the target name as `nis251-gtw`
- On Step 2:
	- Choose `com.awsreinforce.DeviceDefenderCustom` under _My components_
	- Choose `aws.greengrass.Cli` and `aws.greengrass.Nucleus` under _Public components_
- On Step 3, you should see your 3 Selected components. For now, you don't need to do any configuration change. 
- Proceed to Deploy.

After creating the Deployment, devices will receive these deployments, apply them, finally all of them will report their statues to cloud. In final; you'll see the _Core devices_ section in the deployment page as 4 devices reported as _Healthy_.

Now you have your Greengrass devices reporting device-side metrics to AWS IoT Device Defender. Let's check the actual payloads that the component publishes:

```
docker exec -it CONTAINER_ID grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log
```

You can get `CONTAINER_ID`, by running `docker ps`. Copy and paste the output JSON to you favorite JSON parser/viewer to check the metrics published from your devices.

### 5. Use-case #1: Create a security profile

Now that we have our simulated thing created and we have a development environment, we are ready to configure a behavior profile in device defender

1. Navigate to the Security Profiles Section of the Device Defender Console: _AWS IoT -> Device Defender -> Detect -> Security Profiles_
2. Click the "Create Security Profile" button. Select Create Rule-based anomaly Detect Profile. 
	Note: If you have no Security Profiles in your account, you may see a "Create your first security profile" button instead
3. Delete all Cloud-side metrics  for keeping the focus and add Device-side _Packets out_ metric.
4. Name: "NormalNetworkTraffic"
	Under Behaviors
	Name: "PacketsOut"
	Metric: "Packets Out"
	Operator: "Less Than"
	Value: "12000"
	Duration: "5 minutes"
5. On the Alert Targets Page
	SNS Topic: "DeviceDefenderNotifications"
	Role: "DeviceDefenderNotificationRole"
6. Click Next
7. Attach profile to group  `nis251-gtw`.


### 6. Use-case #1: Run the malware condition simulation

Choose one of your devices as the attack target and connect to it. Then run the `ab` tool that generates outbound network activity on the device.

```
docker exec -it CONTAINER_ID /bin/bash
ab -n 40000 https://us-east-1.console.aws.amazon.com/
```

While the `ab` command is running the container, navigate to _AWS IoT Defender > Security Profiles_ to see the Alarms are generated for your device.

In meantime, you can check the published payloads for the device to see metric increases for packets out metric in the payload, using the following command.

```
docker exec -it CONTAINER_ID grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log
```

Once you got the alarm in on the Device Defender Security Profile page, you'll receive an email in the same time. You can stop the network traffic generator tool, which will represent a manual mitigation of the threat on the device by you. So, you can see that the alarm status is removed.

### 7. Use-case #2: Define and enable Device Defender Custom Metrics for GPU resources

To define custom metrics in Device Defender:

1. Go to _AWS IoT > Device Defender > Detect > Metrics_ and click Create.
2. Create the custom metrics as `gpu_load_per_inference` with type = number.
3. Create the custom metrics as `avg_inference_time` with type = number.

Now, AWS IoT Device Defender is able to evaluate two defined custom metrics from the devices. As next, you need to enable Device Defender component to publish those custom metrics.

1. Go to AWS IoT Greengrass console > Deployments
2. Click Revise
3. Proceed to _Step 3 - Configure components_
4. Choose your component and click _Configure component_
5. On the right pane, add the following for _Configuration to merge_

	```
	{
		"EnableGPUMetrics": true
	}
	```

6. Proceed to Deploy

After this deployment, Greengrass device will start appending custom GPU metrics into the metrics payload.

You can check the published payloads for the device to see the custom metrics in the payload, using the following command.

```
docker exec -it CONTAINER_ID grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log
```


### 8. Use-case #2: Create resources for automated actions

You will create a Lambda function that will fire in response to Device Defender Violation SNS events. It will extract the Thing Name of the device that is in violation of the Security Profile and move it to our "Quarantine" thing group, so we can easily find it for further investigation and remediation.

1. Navigate to the AWS Lambda Console
2. Click "Functions" on the left hand menu
3. Click the "Create function" button
4. Select "Blueprints"
5. In search box under Blueprints, search for "sns"
6. Select the "sns-message-python" blueprint and click "Configure"
7. Give your function the name "DeviceDefenderViolation"
8. Select "Choose an Existing Role" in the "Role" drop-down
9. Choose the role "DeviceDefenderBuilderLambda" in the "Existing Role" drop-down
10. Select the SNS Topic that has "DeviceDefenderNotifications" as part of the name
11. Check the "Enable Trigger" checkbox
12. Click the "Create Function" button (we'll get to edit the code in the next step)
13. In the Lambda detail page, edit the function as following:

```
import json
import boto3

def lambda_handler(event, context):
    message = event['Records'][0]['Sns']['Message']
    violation = json.loads(message)
    thing_name = violation["thingName"]
    print("ThingName:" + thing_name)
    client = boto3.client('iot')
    response = client.add_thing_to_thing_group(thingGroupName="Quarantine", thingName=thing_name)
    print(response)
    return message
```
14. Click the save button.


### 9. Use-case #2: Run the cryptocurrency mining condition simulation

In each container, there are two files that represent GPU metrics as `/var/gpu_load_fb` and `/var/gpu_inference_fb`; similar to other available system metrics like CPU temperature, load ...etc. Device Defender component is configured to read metric values from those files for each metric publish operation.

Now, you'll update the values in those files to simulate the condition of a cryptocurrency miner is running on your GPU-powered device, along with your ML model. Increase of GPU load and ML model inference time will represent this situation as an abnormality.

```
docker exec -it CONTAINER_ID bash -c "echo 85 > /var/gpu_load_fb; echo 180 > /var/gpu_inference_fb"
```

After running the update, you can check the published payloads for the device to see the increasing custom metrics in the payload, using the following command.

```
docker exec -it CONTAINER_ID grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log
```

Once metrics are delivered to the Device Defender service and evaluated by the service, you'll receive an e-mail alert but also the device will be added to the _Quarantine_ thing group. Go to _AWS IoT > Manage > Thing groups_ to see if your chosen device is added to the Quarantine device group.


### 10. Cleanup
- Stop and remove all docker containers: `docker-compose down`
- Delete created Greengrass devices
- Delete created AWS IoT Device Defender security profiles
- Delete AWS Lambda function
- Delete SNS subscriptions and the SNS topic

## Cheat Sheet

This section is a collection of useful commands you may need during the Builders' Session, or save your precious time; instead of digging into various online resources.

### Useful docker commands:

```
# List all running docker containers
docker ps
# List all docker containers, including stopped
docker ps -a
# Restart a docker container:
docker restart CONTAINER_ID
# Connect to a docker container
docker exec -it CONTAINER_ID /bin/bash
# See logs of a docker container
docker logs CONTAINER_ID
```

### Useful docker-compose commands:
```
# Create docker containers from docker-compose file
docker-compose up --no-start
# Start all created or stopped containers from docker-compose file
docker-compose start
# Stop all containers from docker-compose file
docker-compose stop
# Stop and remove all containers from docker-compose file
docker-compose down
```

### Useful Greengrass commands:

**NOTE:** You need to run these in the particular devices' Docker container. During this Builder's Session, all GreenGrass clients are running in Docker containers

```
# Restart a Greengrass device: you can simply restart the docker container
docker restart CONTAINER_ID
# List all log files of all Greengrass components:
cd /greengrass/v2/logs && ls
# Tail a log file
tail -f greengrass.log
# Preview and seek in a log file
less greengrass.log
# List recently published Device Defender metric payload logs
#  outside of the container
docker exec -it CONTAINER_ID grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log`
#  inside the container
grep "stdout. Publishing metrics:" /greengrass/v2/logs/com.awsreinforce.DeviceDefenderCustom.log`
# To see a Greengrass container's GPU metric file contents
docker exec -it 23834bb6026c bash -c "echo \"/var/gpu_load_fb = \$(cat /var/gpu_load_fb)\"; echo \"/var/gpu_inference_fb = \$(cat /var/gpu_inference_fb)\""
```

### Greengrass component update and deployment:
If you've made a modification in the component source code and want to deploy your updates; you will need to change the semantic version number in `gdk-config.json`
```
...
 "version": "1.0.11",
...
```

Then run the following to build and publish it:
```
gdk component build
gdk component publish
```

Now your component is published. But your existing deployments still use the previous version and it'll stay unless you revise the deployment with the new version.

1. Go to AWS IoT Greengrass console > Deployments
2. Click Revise
3. Proceed to _Step 3 - Configure components_
4. Choose your component and click _Configure component_
5. Choose the _Component version_ using the dropdown menu and save
6. Proceed to Deploy
