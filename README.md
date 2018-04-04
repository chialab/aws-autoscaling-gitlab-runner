Autoscaling GitLab Runner on AWS [![Launch this stack on AWS](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=GitLabRunner&templateURL=https://s3-eu-west-1.amazonaws.com/chialab-cloudformation-templates/Chialab/aws-autoscaling-gitlab-runner/master/runner.yml)
================================================================================

This repository consists of an AWS CloudFormation template that may be used
to deploy a GitLab runner with Docker executor and auto-scaling based on number
of builds on AWS.

The runners have a shared cache to speed up builds. Objects in the bucket are
automatically expired after a configurable number of days — 0 means that
cache objects will never expire.

Resources created
-----------------

* **1 S3 bucket** to store runners' cache.
* **1 EC2 instance** that is the runners' manager: it invokes AWS APIs to spawn
    and terminate other EC2 instances (via `docker-machine`) and runs Docker
    containers on them to process GitLab CI builds.

Obtaining a GitLab Runner token
-------------------------------

When you launch the stack you are required to pass a GitLab Runner token.
**This is not to be confused with a GitLab Runner registration token!**

You can obtain a registration token by navigating to the "Settings › CI / CD"
page of any project for which you have administrative rights. It'll be available
under "Runners settings".

You can then obtain a GitLab Runner token by using the (undocumented) endpoint
`POST /runners`:

```bash
# Assuming the GitLab instance is available at https://gitlab.example.org
# and the GitLab Runner registration token is "abcdef1234567890":

curl -XPOST -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"token":"abcdef1234567890","run_untagged":true,"locked":false}' \
  https://gitlab.example.org/api/v4/runners
```

If everything goes fine, the response will be a JSON that has a `token` key:
this is the GitLab Runner token you were looking for.

Security considerations
-----------------------

### AWS credentials

Credentials must be rotated, and humans must remember to rotate credentials.
But credentials are not always strictly necessary.

The runners' manager instance has an AWS Instance Profile attached that makes it
possible to invoke EC2 and S3 APIs using dynamically obtained credentials, that
have a short lifetime and therefore don't need to be rotated. Thus, no IAM
access keys are involved in this stack — except the ones you may use to create
or update the stack using the AWS APIs or the CLI, of course.

### GitLab CI token

The only credential that is actually stored somewhere is the GitLab CI token.
If stolen, it would allow a malicious user to "intercept" your builds and run
them on their infrastructure, exposing other secrets as a consequence.
You should treat this as a very sensitive information.

This stack doesn't provide any special security measure: the value is passed as
plain text to CloudFormation at stack creation as a "sensitive parameter"
(`NoEcho: true`), and is stored in plain text on the runners' manager in a file
that is readable only by `gitlab-runner` user. The provisioning of said file
happens via `cfn-init`. The value is then used by GitLab Runner itself,
presumably in HTTP-over-TLS communications with the GitLab instance.

### SSH

At stack creation you are required to specify an AWS Key Pair to provide access
to the runners' manager instance. When the stack is created, you can access
your instance with the following command:

```bash
ssh -i /PATH/TO/IDENTITY_FILE ec2-user@INSTANCE-PUBLIC-IP
```

The runners' manager Security Group allows connections on port 22 by any IPv4
address (CIDR: `0.0.0.0/0`), and all other ports are unaccessible. This is far
from being an optimal solution but, since SSH authentication requires an SSH key
pair, it should be pretty safe anyways. Counter-measures like Fail2Ban are
not deployed out of the box, either.
