#!/bin/bash

cd /home/dima/myPlaybook/playbook_selenoid/jenkins_jobs

# Установка jenkins-job-builder
pip3 install jenkins-job-builder

# Загрузка всех джоб
jenkins-jobs --conf jenkins-job-builder.ini update templates/

echo "Jobs uploaded successfully"