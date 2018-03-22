# Discovery News CI/CD Pipeline to Multi Cloud with Gitlab and Jenkins

## Client Machine Pre-requisites
1. Install [Git Desktop](https://desktop.github.com/)
2. Install [Visual Studio Code](https://code.visualstudio.com/)
3. Java runtime
4. Install ICP CLI:
   - [IBM CLoud CLI](https://console.bluemix.net/docs/cli/reference/bluemix_cli/all_versions.html)
   - Download ICP Plugin for IBM Cloud CLI: `https://your-icp-master-node:8443/console/tools/cli`
   - Install the downloaded [ICP Plugin for IBM Cloud CLI](https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/manage_cluster/install_cli.html):
`bx plugin install <replace-with-path-to-your-downloaded-plugin-file>`
5. Install [Helm Client](https://github.com/kubernetes/helm)
6. Deploy Gitlab and Jenkins
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
3. If you have not deployed Jenkins and Gitlab chart, run this script: `install_charts.sh`
4. Wait and verify the charts deployment until completed
5. Execute `setupci.sh`. In this script you will be prompted for gitlab credential. Enter the Gitlab username and password you defined in `.env.setupci`
6. Create Jenkins user described in `.env.setupci` manually:
   - Login to jenkins with default `admin` user. The password can be queried from:
   ```
   kubectl get secrets <your-jenkins-secret> -o jsonpath='{.data.jenkins-admin-password}' | base64 -D; echo
   ```
   - Navigate to Jenkins > Manage Jenkins > Configure Global Security
   - Change the *Access Control* **Security Realm** value to `Jenkins' own user database`
   - Save and logout
   - Open the `Create an account` link and create your Jenkins account as defined in `.env.setupci`
7. Configure Jenkins as described in [Gitlab integration](https://github.com/pjgunadi/icp-jenkins-gitlab)

8. Execute `setup_jenkins.sh` to create Pipeline and required credentials in Jenkins.

## Create AWS S3 Bucket for Public Cloud Deployment
1. Create AWS account if needed and login to [AWS Console](https://aws.amazon.com/console/)
2. Open [Amazon S3](https://s3.console.aws.amazon.com/s3) and click `+ Create bucket`
3. Enter the *Bucket name* and *Region* and continue the instruction until the bucket is created
4. Edit `aws/variable.tf` and `sl/variable.tf` file. Update the `s3_bucket` and `s3_region` default value to the bucket name and region you created

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