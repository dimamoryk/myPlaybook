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
if [ -z "$JENKINS_PASSWORD" ]; then
    echo -e "${RED}❌ Переменная JENKINS_PASSWORD не задана.${NC}"
    echo "Экспортируйте: export JENKINS_PASSWORD='admin1985'"
    exit 1
fi

JENKINS_URL="http://localhost:8080/my_jenkins/"
AUTH="admin:${JENKINS_PASSWORD}"

echo "🔍 Проверяем доступность Jenkins..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${JENKINS_URL}api/json" --user "${AUTH}" 2>/dev/null)

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}❌ Jenkins недоступен (HTTP ${HTTP_CODE})${NC}"
    echo "Проверь:"
    echo "  - Jenkins запущен: docker ps | grep jenkins"
    echo "  - Пароль: ${JENKINS_PASSWORD}"
    echo "  - URL: ${JENKINS_URL}"
    exit 1
fi
echo -e "${GREEN}✅ Jenkins доступен${NC}"

echo "🔐 Добавляем GitHub credentials..."
CRED_CHECK=$(curl -s -X GET "${JENKINS_URL}credentials/store/system/domain/_/credential/github-credentials/api/json" --user "${AUTH}" 2>/dev/null | grep -c "id")

if [ "$CRED_CHECK" -eq 0 ]; then
    cat > /tmp/github_creds.xml << EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>github-credentials</id>
  <description>GitHub credentials</description>
  <username>dimamoryk</username>
  <password>${GITHUB_TOKEN}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
    curl -X POST "${JENKINS_URL}credentials/store/system/domain/_/createCredentials" \
        --user "${AUTH}" \
        --header "Content-Type: application/xml" \
        --data-binary @/tmp/github_creds.xml 2>/dev/null
    echo -e "${GREEN}✅ GitHub credentials добавлены${NC}"
else
    echo -e "${GREEN}✅ GitHub credentials уже существуют${NC}"
fi

declare -A JOBS=(
    ["UI-Tests"]="https://github.com/dimamoryk/AutotestWithSelenoid.git"
    ["API-Tests"]="https://github.com/dimamoryk/RestAssuredAutoTest.git"
    ["Mobile-Tests"]="https://github.com/dimamoryk/AutoTestWithMobileAppium.git"
    ["Cucumber-Tests"]="https://github.com/dimamoryk/AutotestWithCucumber.git"
    ["Selenide-Tests"]="https://github.com/dimamoryk/AutoTestWithSelenide.git"
    ["Playwright-Tests"]="https://github.com/dimamoryk/AutoTestWithPlayWright2.git"
)

JOB_XML='<?xml version="1.1" encoding="UTF-8"?>
<flow-definition plugin="workflow-job">
  <description>Автотесты</description>
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
</flow-definition>'

for JOB_NAME in "${!JOBS[@]}"; do
    REPO_URL="${JOBS[$JOB_NAME]}"
    echo "📦 Создаю джобу: ${JOB_NAME}"
    JOB_XML_FINAL="${JOB_XML/REPO_URL_PLACEHOLDER/$REPO_URL}"

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "${JENKINS_URL}createItem?name=${JOB_NAME}" \
        --user "${AUTH}" \
        --header "Content-Type: application/xml" \
        --data-binary "${JOB_XML_FINAL}" 2>/dev/null)

    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "201" ]; then
        echo -e "${GREEN}   ✅ Джоба ${JOB_NAME} создана${NC}"
    elif [ "$RESPONSE" = "409" ]; then
        echo -e "   ⚠️  Джоба ${JOB_NAME} уже существует"
    else
        echo -e "${RED}   ❌ Ошибка (HTTP ${RESPONSE})${NC}"
    fi
done

echo -e "${GREEN}🎉 Деплой завершён!${NC}"
echo "📋 Проверь джобы: ${JENKINS_URL}"