# Discovery News CI/CD Pipeline to Multi Cloud with Gitlab and Jenkins

## Client Machine Pre-requisites
1. Install [Git Desktop](https://desktop.github.com/)
2. Install [Visual Studio Code](https://code.visualstudio.com/)
3. Java runtime
4a. Install ICP CLI (Version 3.1.0):
   - Download ICP CLI, Kubectl CLI, and Helm from your ICP: `https://your-icp-master-node:8443/console/tools/cli`
   - Install the downloaded [ICP CLI](https://www.ibm.com/support/knowledgecenter/SSBS6K_3.1.0/manage_cluster/install_cli.html)
   - Install the downloaded [Kubectl CLI](https://www.ibm.com/support/knowledgecenter/SSBS6K_3.1.0/manage_cluster/cfc_cli.html)
   - Install the downloaded [Helm](https://www.ibm.com/support/knowledgecenter/SSBS6K_3.1.0/app_center/create_helm_cli.html)

4b. Install ICP CLI (Version 2.1.0.3 or earlier):
   - [IBM Cloud CLI](https://console.bluemix.net/docs/cli/reference/bluemix_cli/all_versions.html)
   - Download ICP Plugin for IBM Cloud CLI: `https://your-icp-master-node:8443/console/tools/cli`
   - Install the downloaded [ICP Plugin for IBM Cloud CLI](https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/manage_cluster/install_cli.html):
`bx plugin install <replace-with-path-to-your-downloaded-plugin-file>`
   - Install [Helm Client](https://github.com/kubernetes/helm)
5. Deploy Gitlab and Jenkins
   Choose one of the following methods:
   - [Step by Step](https://github.com/pjgunadi/icp-jenkins-gitlab) in ICP Cluster
   - Use script from the instructions provided in Deployment steps

## Create Discovery News Service
1. [Register to IBM Cloud](https://console.bluemix.net/registration/) if you do not have an account
2. Login to IBM Cloud and open [Catalog](https://console.bluemix.net/catalog)
3. Search for `discovery` service under *Watson*
4. Open **Discovery** service, choose Pricing Plan. Lite plan (Free) is selected by default. Click `Create`
5. Open [Dashboard](https://console.bluemix.net/dashboard/apps) and double click the created discovery service under **Cloud Foundry Services** section
6. Select `Service credentials`, click `New credential`, and click `Add` on confirmation dialog
7. Open `View credentials` drop down on the created credential row, record the value of `username` and `password`. This credential will be used in deployment steps.

## Deployment Steps
Use shell script to deploy Gitlab and Jenkins. Jenkins system configuration should be done manually from UI.
1. Clone this repository
2. Rename [sample.env.setupci](sample.env.setupci) to `.env.setupci` and update the variables
3. If your not installed helm client or the version is not the same as the helm server in ICP, run this script: `install_helm.sh`
4. If you have not deployed Jenkins and Gitlab chart, run this script: `install_gitlabce_jenkins.sh`
5. Wait and verify the charts deployment until all pods are READY. You can use this command to watch the pods: `kubectl get pods -w`
6. Execute `setupci.sh`. In this script you will be prompted for gitlab credential. Enter the Gitlab username and password you defined in `.env.setupci`
7. Configure Jenkins:
   - Login to Jenkins with url, username, and password printed from previous step
   - Open Jenkins > Manage Jenkins > Configure System
      - Under **Gitlab** section, untick `Enable authentication for '/project' end-point`
      - Under **Cloud** section, **Kubernetes** sub section, increase `Container Cap` value `1000`
      - Save configuration
   - Open Jenkins > Manage Jenkins > Configure Global Security: 
      - Under **Agents** section, verify the `Agent protocols` and untick the deprecated protocols
   - Update `JENKINS_USER_API_TOKEN` in `.env.setupci` manually:
      - Open `Admin` user configuration and copy the value of **API Token**
      - Update `JENKINS_USER_API_TOKEN` value `.env.setupci`
8. Execute `setup_jenkins.sh` to create Pipeline and required credentials in Jenkins.

## Create AWS S3 Bucket for Public Cloud Deployment
1. Create AWS account if needed and login to [AWS Console](https://aws.amazon.com/console/)
2. Open [Amazon S3](https://s3.console.aws.amazon.com/s3) and click `+ Create bucket`
3. Enter the *Bucket name* and *Region* and continue the instruction until the bucket is created
4. Edit `aws/backend.tf` and `sl/backend.tf` file. Update the `bucket` and `region` value to the bucket name and region you created

## DevOps Showcase
1. Clone this repository
2. Open Discovery News URL
3. Initialize Git
4. Update source code: `app/src/layout.jsx`
  - change the Discovery 1.0 to 1.1 below
```
<Jumbotron
  serviceName="Discovery 1.0"
  repository="https://github.com/watson-developer-cloud/discovery-nodejs"
  documentation="https://console.bluemix.net/docs/services/discovery/index.html"
  apiReference="http://www.ibm.com/watson/developercloud/discovery/api"
  startInBluemix="https://console.ng.bluemix.net/registration/?target=/catalog/services/discovery/"
  version="GA"
  description="Unlock hidden value in data to find COOL answers, monitor trends and surface patterns, with the world’s most advanced cloud-native insight engine."
/>
```
5. Click `+` on the Changed Files
6. Commit Change
- **Username**: *as defined in .env.setupci*
- **Password**: *as defined in .env.setupci*
7. Push to Gitlab
8. Observe the Pipeline auto triggered in Jenkins
9. Verify Discovery News URL. The url can be obtained from the pipeline stage log.

## Reference
Discovery News is forked from [watson-developer-cloud/discovery-nodejs](https://github.com/watson-developer-cloud/discovery-nodejs) and copied under app folder in this repository