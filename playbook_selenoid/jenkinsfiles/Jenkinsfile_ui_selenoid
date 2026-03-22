pipeline {
    agent any

    environment {
        SELENOID_URL = "${params.SELENOID_URL}"
        BROWSER = "${params.BROWSER}"
        DOCKER_HOST = "unix:///var/run/docker.sock"
    }

    parameters {
        string(name: 'BROWSER', defaultValue: 'chrome', description: 'Браузер: chrome/firefox')
        string(name: 'BROWSER_VERSION', defaultValue: 'latest', description: 'Версия браузера')
        string(name: 'SELENOID_URL', defaultValue: 'http://selenoid1:4444', description: 'Selenoid Grid URL')
        choice(name: 'TESTS_SCOPE', choices: ['all', 'smoke', 'regression'], description: 'Объем тестов')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/dimamoryk/AutotestWithSelenoid.git',
                    credentialsId: 'github-credentials'
            }
        }

        stage('Run UI Tests') {
            steps {
                sh '''
                    mvn clean test \
                        -Dselenoid.url=${SELENOID_URL} \
                        -Dbrowser=${BROWSER} \
                        -Dbrowser.version=${BROWSER_VERSION} \
                        -Dtest.scope=${TESTS_SCOPE}
                '''
            }
        }

        stage('Publish Reports') {
            steps {
                publishHTML([
                    reportDir: 'target/surefire-reports',
                    reportFiles: '*.html',
                    reportName: 'UI Test Reports'
                ])
                junit 'target/surefire-reports/*.xml'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            echo 'UI tests failed!'
        }
        success {
            echo 'UI tests passed successfully!'
        }
    }
}