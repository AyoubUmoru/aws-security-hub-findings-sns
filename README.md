# Welcome to the SecurityHub Event Filter Project

This project contains code to build infrastructure to capture SecurityHub Findings for further processing.

In this ready-to-use code, it deploys and triggers 2 ssn topics, depending on the severity of the finding.


## Architecture

* sns topic for CRITICAL findings
* sns topic for HIGH findings
* lambda for processing Security Hub Events
* role for the lambda
* cloud watch log group for log output

## Deployment
* terraform apply

## Prerequisites

* terraform