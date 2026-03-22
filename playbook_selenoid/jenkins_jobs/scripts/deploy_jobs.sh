#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Переменная GITHUB_TOKEN не задана.${NC}"
    echo "Экспортируйте: export GITHUB_TOKEN='ваш_токен'"
    exit 1
fi

echo "🚀 Начинаем деплой джоб в Jenkins..."

JENKINS_PASS="${JENKINS_PASSWORD}"
if [ -z "$JENKINS_PASS" ]; then
    echo -e "${RED}❌ Переменная JENKINS_PASSWORD не задана.${NC}"
    echo "Экспортируйте: export JENKINS_PASSWORD='ваш_пароль'"
    exit 1
fi

JENKINS_URL="http://localhost:8080"
AUTH="admin:${JENKINS_PASS}"

echo "🔍 Проверяем доступность Jenkins..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}/api/json" --user "${AUTH}")
if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}❌ Jenkins недоступен или неправильный пароль (HTTP ${HTTP_CODE})${NC}"
    exit 1
fi

CRUMB_JSON=$(curl -s --user "${AUTH}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "$CRUMB_JSON" | grep -o '"crumb":"[^"]*"' | cut -d'"' -f4)
CRUMB_FIELD=$(echo "$CRUMB_JSON" | grep -o '"crumbRequestField":"[^"]*"' | cut -d'"' -f4)
if [ -n "$CRUMB" ] && [ -n "$CRUMB_FIELD" ]; then
    HEADER="$CRUMB_FIELD: $CRUMB"
    echo -e "${GREEN}✅ Crumb получен${NC}"
else
    echo -e "${YELLOW}⚠️ Crumb не найден (возможно, CSRF отключён)${NC}"
    HEADER=""
fi

echo "🔐 Добавляем GitHub credentials..."
CRED_EXISTS=$(curl -s -X GET "${JENKINS_URL}/credentials/store/system/domain/_/credential/github-credentials/api/json" --user "${AUTH}" | grep -c "description")
if [ "$CRED_EXISTS" -eq 0 ]; then
    cat > /tmp/github_creds.xml << EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>github-credentials</id>
  <description>GitHub credentials for dimamoryk</description>
  <username>dimamoryk</username>
  <password>${GITHUB_TOKEN}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
    curl -X POST "${JENKINS_URL}/credentials/store/system/domain/_/createCredentials" \
        --user "${AUTH}" \
        --header "Content-Type: application/xml" \
        ${HEADER:+ -H "$HEADER"} \
        --data-binary @/tmp/github_creds.xml
    echo -e "${GREEN}✅ GitHub credentials добавлены${NC}"
else
    echo -e "${GREEN}✅ GitHub credentials уже существуют${NC}"
fi

declare -A JOBS=(
    ["UI-Tests-Selenoid"]="https://github.com/dimamoryk/AutotestWithSelenoid.git"
    ["API-Tests-RestAssured"]="https://github.com/dimamoryk/RestAssuredAutoTest.git"
    ["Mobile-Tests-Appium"]="https://github.com/dimamoryk/AutoTestWithMobileAppium.git"
    ["Cucumber-Tests"]="https://github.com/dimamoryk/AutotestWithCucumber.git"
    ["Selenide-Tests"]="https://github.com/dimamoryk/AutoTestWithSelenide.git"
    ["Playwright-Tests"]="https://github.com/dimamoryk/AutoTestWithPlayWright2.git"
    ["Expectations-Tests"]="https://github.com/dimamoryk/AutotestWithExpectations1.git"
)

JOB_XML_TEMPLATE='<?xml version="1.1" encoding="UTF-8"?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Автотесты</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>REPO_URL_PLACEHOLDER</url>
          <credentialsId>github-credentials</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>'

for JOB_NAME in "${!JOBS[@]}"; do
    REPO_URL="${JOBS[$JOB_NAME]}"
    echo "📦 Создаю джобу: ${JOB_NAME}"
    JOB_XML="${JOB_XML_TEMPLATE/REPO_URL_PLACEHOLDER/$REPO_URL}"
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "${JENKINS_URL}/createItem?name=${JOB_NAME}" \
        --user "${AUTH}" \
        --header "Content-Type: application/xml" \
        ${HEADER:+ -H "$HEADER"} \
        --data-binary "${JOB_XML}")
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "201" ]; then
        echo -e "${GREEN}   ✅ Джоба ${JOB_NAME} создана${NC}"
    elif [ "$RESPONSE" = "409" ]; then
        echo -e "   ⚠️  Джоба ${JOB_NAME} уже существует"
    else
        echo -e "${RED}   ❌ Ошибка при создании ${JOB_NAME} (HTTP ${RESPONSE})${NC}"
    fi
done

echo -e "${GREEN}🎉 Деплой завершён!${NC}"
echo "📋 Проверь джобы: http://localhost:8080/my_jenkins/"