# testapp-jenkins-deploy

```
Jenkins:  http://your_ip_or_domain:8080

Jenkins (Port 8080) is an open source, Java-based automation server that offers an easy way to set up a continuous integration and continuous delivery (CI/CD) pipeline.

Continuous integration (CI) is a DevOps practice in which team members regularly commit their code changes to the version control repository, after which automated builds and tests are run. Continuous delivery (CD) is a series of practices where code changes are automatically built, tested and deployed to production.

   Build, Test & Deploy phases.

   1: Provision an instance with Terraform.

$ git clone https://github.com/rgdevops123/terraform-aws-ec2-instance-ubuntu
$ cd terraform-aws-ec2-instance
   Follow README.md instructions.


Disable Firewall on Ubuntu 18.04
$ sudo ufw status
$ sudo ufw disable
$ sudo systemctl disable ufw
$ sudo systemctl stop ufw


    Install Docker:
$ sudo apt -y install docker.io
$ sudo systemctl start docker
$ sudo systemctl enable docker


   Create a custom Jenkins Docker Image:
$ mkdir jenkins-devops
$ cd jenkins-devops

$ vim Dockerfile
+++
# Starting off with the Jenkins base Image.
FROM jenkins/jenkins
 
USER root

# Installing the Plugins we need using the in-built install-plugins.sh script.
RUN /usr/local/bin/install-plugins.sh git matrix-auth workflow-aggregator docker-workflow blueocean credentials-binding
 
# Setting up Environment Variables for Jenkins Admin User.
ENV JENKINS_USER admin
ENV JENKINS_PASS admin
 
# Skip the Initial Setup Wizard.
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
 
# Start-up script to create the Admin User.
COPY default-user.groovy /usr/share/jenkins/ref/init.groovy.d/
+++


$ vim default-user.groovy
+++
import jenkins.model.*
import hudson.security.*

def env = System.getenv()

def jenkins = Jenkins.getInstance()
jenkins.setSecurityRealm(new HudsonPrivateSecurityRealm(false))
jenkins.setAuthorizationStrategy(new GlobalMatrixAuthorizationStrategy())

def user = jenkins.getSecurityRealm().createAccount(env.JENKINS_USER, env.JENKINS_PASS)
user.save()

jenkins.getAuthorizationStrategy().add(Jenkins.ADMINISTER, env.JENKINS_USER)
jenkins.save()
+++



$ sudo docker build -t jenkins-devops .

$ sudo docker run -d --rm --name jenkins-devops -p 8080:8080 -p 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):/usr/bin/docker --privileged=true jenkins-devops


   :REFERENCE:
$ sudo docker run -d --rm --name jenkins-devops -p 8080:8080 
-p 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock
-v $(which docker):/usr/bin/docker --privileged=true jenkins-devops
   :REFERENCE:



         GITHUB: https://github.com/rgdevops123/testapp-jenkins-deploy

$ sudo docker ps -a


Stream the Container's logs:
$ sudo docker logs --follow jenkins-devops

http://jenkins-server:8080
Username: admin
Password: admin



         Part 1: The Web Application with Docker.

   Create a Test Flask Application:
      $ cd ~
      $ git clone https://github.com/rgdevops123/testapp-jenkins-deploy

$ vim requirements.txt
+++
flask
xmlrunner
+++

$ sudo apt -y install python3-pip
$ sudo pip3 install -r requirements.txt


$ vim app.py
+++
#!/usr/bin/python3

from flask import Flask


app = Flask(__name__)


@app.route('/')
@app.route('/hello/')
def hello_world():
    return 'Hello World!\n'


@app.route('/hello/<username>')  # Dynamic route.
def hello_user(username):
    return 'Why Hello %s!\n' % username


if __name__ == '__main__':
    app.run(host='0.0.0.0')      # Open for everyone.
+++


$ chmod +x app.py

$ ./app.py &



   Test the server:
$ curl -i localhost:5000/
$ curl -i localhost:5000/hello/
$ curl -i localhost:5000/hello/John




         The Unit Tests

   Write some tests to test these routes.

$ vim test.py
+++
#!/usr/bin/python3
import unittest
import app


class TestHello(unittest.TestCase):

    def setUp(self):
        app.app.testing = True
        self.app = app.app.test_client()

    def test_hello(self):
        rv = self.app.get('/')
        self.assertEqual(rv.status, '200 OK')
        self.assertEqual(rv.data, b'Hello World!\n')

    def test_hello_hello(self):
        rv = self.app.get('/hello/')
        self.assertEqual(rv.status, '200 OK')
        self.assertEqual(rv.data, b'Hello World!\n')

    def test_hello_name(self):
        name = 'John'
        rv = self.app.get(f'/hello/{name}')
        self.assertEqual(rv.status, '200 OK')
        self.assertIn(bytearray(f"{name}", 'utf-8'), rv.data)


if __name__ == '__main__':
    import xmlrunner
    unittest.main(testRunner=xmlrunner.XMLTestRunner(output='test-reports'))
    unittest.main()
+++



$ chmod +x test.py


   Run the Tests:

$ ./test.py


   Check the reports in test-reports.
$ cat test-reports/TEST-TestHello-<TIME_AND_DATE_OF_TEST>.xml



   Create a Dockerfile, Docker Image and Container:

$ sudo apt -y install docker.io
$ sudo systemctl start docker
$ sudo systemctl enable docker


$ vim Dockerfile
+++
# Use a Python 3.6 Base Image.
FROM python:3.6

# Set Maintainer.
LABEL maintainer "rgdevops123@gmail.com"

# Copy Application files.
COPY app.py requirements.txt test.py /

# Install Dependencies.
RUN pip install -r requirements.txt

# Set a Health Check.
HEALTHCHECK --interval=5s \
            --timeout=5s \
            CMD curl -f http://127.0.0.1:5000 || exit 1

# tell docker what port to expose
EXPOSE 5000

# Specify the command to run.
ENTRYPOINT ["python","app.py"]
+++


   Build the Image.
$ sudo docker build . -t rgdevops123/testapp-jenkins-deploy

   Confirm:
$ sudo docker images


   Create a Container from the image.
$ sudo docker run -d --rm --name testapp-jenkins-deploy -p 5000:5000 rgdevops123/testapp-jenkins-deploy

   Confirm:
$ sudo docker ps
http://127.0.0.1:5000/




         Part 3: The Jenkins Pipeline

 Create a Jenkins CI Pipeline by creating a Jenkinsfile. 
  The Jenkinsfile is a Groovy script 
  and can use a DSL-like syntax to define our stages 
  and shell instructions.


   The Jenkinsfile:
      Three stages: Build, Test and Deploy for our current pipeline.
$ vim Jenkinsfile
+++
node {
    def app

    stage('Clone repository') {
        /* Let's make sure we have the repository cloned to our workspace */

        checkout scm
    }

    stage('Build image') {
        /* This builds the actual image; synonymous to
         * docker build on the command line */

        app = docker.build("rgdevops123/testapp-jenkins-deploy")
    }

    stage('Test image') {
        /* Run a test framework against our image. */

        app.inside {
            sh 'python test.py'
        }
    }

    stage('Push image') {
        /* Finally, we'll push the image with two tags:
         * First, the incremental build number from Jenkins
         * Second, the 'latest' tag. */
        docker.withRegistry('https://registry.hub.docker.com', 'docker-hub-credentials') {
            app.push("${env.BUILD_NUMBER}")
            app.push("latest")
        }
    }
}
+++

$ git commit -am "Added Jenkinsfile."
$ git push


      In Jenkins Console:

         http://jenkins-server:8080
         Username: admin
         Password: admin

   *Manage Jenkins
   *Manage Plugins
   *Select: GitHub Integration
   *Select: Restart Jenkins after restart.


   GITHUB:
https://github.com/rgdevops123/testapp-jenkins-deploy/settings/hooks/new   (WEBHOOKS)
http://18.219.19.223:8080/github-webhook/
JSON
Just Push


   JENKINS:
Use this webhook in Jenkins.

    Go to Manage Jenkins -> Configure System
    Scroll down and you will find the GitHub Pull Requests checkbox. 
      In the Published Jenkins URL, add the repository link
   https://github.com/rgdevops123/testapp-jenkins-deploy
    Click on "Save."



   Import the Project

After logging in to your Jenkins server, you’ll want to import a pipeline. 
This code will have to be checked into a Git repository (or other Source Code Manager)
and then configured to fetch the Jenkinsfile from that repository.

      New Item:
   Options...
Build Triggers: GitHub hook trigger for GITScm polling
Select: Pipeline Script from SCM
SCM: GIT
Repository URL: https://github.com/rgdevops123/testapp-jenkins-deploy



   Test by updating git repo and watch the CI/CD.
```
