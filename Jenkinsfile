pipeline {
    agent any

    environment {
        // Harbor
        HARBOR_REGISTRY = 'localhost:8082'
        HARBOR_PROJECT = 'cicd-demo'
        IMAGE_NAME = 'app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        // SonarQube
        SONAR_HOST = 'http://sonarqube:9000'

        // Kubernetes
        // KUBECONFIG = credentials('kubeconfig')  // Commented out - configure in Jenkins Credentials if needed
        NAMESPACE = 'default'
    }

    stages {
        stage('Setup Maven Wrapper') {
            steps {
                script {
                    sh '''#!/bin/bash
                        set -e
                        echo "=== Checking for Maven ==="

                        # Check common Maven installation locations
                        MAVEN_FOUND=false

                        for MVN_PATH in "/opt/maven/bin/mvn" "/usr/share/maven/bin/mvn" "/usr/local/maven/bin/mvn" "$(which mvn 2>/dev/null || true)"; do
                            if [ -n "$MVN_PATH" ] && [ -x "$MVN_PATH" ]; then
                                echo "Found Maven at: $MVN_PATH"
                                export PATH="$(dirname $MVN_PATH):$PATH"
                                MAVEN_FOUND=true
                                break
                            fi
                        done

                        if [ "$MAVEN_FOUND" = "false" ]; then
                            echo "Maven not found in system. Setting up Maven Wrapper..."
                            if [ ! -f "mvnw" ]; then
                                echo "Downloading Maven Wrapper..."
                                curl -s -o mvnw https://raw.githubusercontent.com/takari/maven-wrapper/master/mvnw
                                chmod +x mvnw
                                mkdir -p .mvn/wrapper
                                curl -s -o .mvn/wrapper/maven-wrapper.jar https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.2.0/maven-wrapper-3.2.0.jar
                                curl -s -o .mvn/wrapper/maven-wrapper.properties https://raw.githubusercontent.com/takari/maven-wrapper/master/.mvn/wrapper/maven-wrapper.properties
                                echo "Maven Wrapper downloaded successfully"
                            else
                                echo "Maven Wrapper already exists"
                            fi
                        fi

                        # Verify Maven is working
                        echo "=== Verifying Maven ==="
                        if command -v mvn >/dev/null 2>&1; then
                            mvn --version
                        elif [ -f "./mvnw" ]; then
                            ./mvnw --version
                        else
                            echo "ERROR: Neither system Maven nor Maven Wrapper is available!"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    // Ensure a full, clean checkout so the build context contains all files (including src/)
                    checkout([$class: 'GitSCM', branches: scm.branches, userRemoteConfigs: scm.userRemoteConfigs,
                              doGenerateSubmoduleConfigurations: false,
                              extensions: [
                                  [$class: 'CleanBeforeCheckout'],
                                  [$class: 'CloneOption', noTags: false, shallow: false, depth: 0]
                              ]
                    ])
                }
                echo "Building version ${IMAGE_TAG}"
            }
        }

        stage('Maven Build') {
            steps {
                script {
                    // Use system mvn if available, otherwise use wrapper. Add diagnostics and ensure wrapper is executable.
                    sh '''#!/bin/bash
                        set -e
                        echo "Maven build: PWD=$(pwd)"
                        echo "Workspace top-level:"; ls -la || true
                        echo "Checking for mvn and mvnw..."
                        if command -v mvn >/dev/null 2>&1; then
                            echo "Found system mvn: $(mvn --version | head -n1)"
                            mvn clean package -DskipTests
                        else
                            if [ -f ./mvnw ]; then
                                echo "Found mvnw in workspace. Ensuring executable bit and running wrapper..."
                                chmod +x ./mvnw || true
                                ls -la ./mvnw || true
                                if [ -x ./mvnw ]; then
                                    ./mvnw clean package -DskipTests
                                else
                                    echo "mvnw exists but is not executable; attempting to run with sh"
                                    sh ./mvnw clean package -DskipTests
                                fi
                            else
                                echo "mvnw not found in workspace — attempting to download Maven Wrapper files as a fallback"
                                # Attempt to download the takari maven wrapper files (best-effort)
                                set -e
                                echo "Downloading mvnw and wrapper jars..."
                                curl -s -o mvnw https://raw.githubusercontent.com/takari/maven-wrapper/master/mvnw || true
                                chmod +x mvnw || true
                                mkdir -p .mvn/wrapper || true
                                curl -s -o .mvn/wrapper/maven-wrapper.jar https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.2.0/maven-wrapper-3.2.0.jar || true
                                curl -s -o .mvn/wrapper/maven-wrapper.properties https://raw.githubusercontent.com/takari/maven-wrapper/master/.mvn/wrapper/maven-wrapper.properties || true
                                if [ -f ./mvnw ]; then
                                    echo "Downloaded mvnw, running wrapper..."
                                    chmod +x ./mvnw || true
                                    ./mvnw clean package -DskipTests
                                else
                                    echo "ERROR: Failed to obtain mvnw. Please ensure repository is fully checked out or disable lightweight checkout in job settings."
                                    exit 1
                                fi
                            fi
                        fi
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                script {
                    sh '''
                        if command -v mvn >/dev/null 2>&1; then
                            mvn test
                        else
                            ./mvnw test
                        fi
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                }
            }
        }

/*
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    script {
                        sh '''
                            if command -v mvn >/dev/null 2>&1; then
                                mvn sonar:sonar
                            else
                                ./mvnw sonar:sonar
                            fi
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
*/

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} .
                        docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                                   ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Push to Harbor') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh """
                        echo \$PASS | docker login ${HARBOR_REGISTRY} -u \$USER --password-stdin
                        docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Update Helm Chart') {
            steps {
                script {
                    // Update the Helm chart values with the new image tag
                    sh """
                        cd helm-charts/cicd-demo
                        # Fix sed for Linux (remove macOS-specific empty string after -i)
                        sed -i 's/tag: .*/tag: "${IMAGE_TAG}"/' values.yaml
                        cat values.yaml | grep tag:
                    """

                    // Commit and push changes using Git credentials
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_TOKEN'
                    )]) {
                        sh """
                            # Configure git
                            git config user.email "jenkins@cicd.local"
                            git config user.name "Jenkins CI"

                            # Add and commit the changes
                            cd helm-charts/cicd-demo
                            git add values.yaml

                            # Commit (only if there are changes)
                            git diff --cached --quiet || git commit -m "ci: Update image tag to ${IMAGE_TAG} [skip ci]"

                            # Push using credentials
                            git push https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/gmedeirosnet/CI.CD.git HEAD:main || echo "No changes to push or push failed"
                        """
                    }
                }
            }
        }

        stage('Deploy with ArgoCD') {
            steps {
                script {
                    sh """
                        # Create ArgoCD application if it doesn't exist
                        argocd app create cicd-demo \
                            --repo https://github.com/gmedeirosnet/CI.CD.git \
                            --path helm-charts/cicd-demo \
                            --dest-server https://kubernetes.default.svc \
                            --dest-namespace ${NAMESPACE} \
                            --sync-policy automated \
                            --auto-prune \
                            --self-heal \
                            2>/dev/null || echo "ArgoCD app already exists"

                        # Sync and wait for deployment
                        argocd app sync cicd-demo --timeout 300
                        argocd app wait cicd-demo --timeout 300

                        # Show application status
                        argocd app get cicd-demo
                    """
                }
            }
        }

        stage('Ansible Post-Deploy') {
            steps {
                sh """
                    cd ansible
                    ansible-playbook -i inventory.ini deploy.yml
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                sh """
                    kubectl get pods -n ${NAMESPACE}
                    kubectl get svc -n ${NAMESPACE}
                """
            }
        }
    }

    post {
        success {
            echo 'Pipeline succeeded!'
            echo "Application deployed with image tag: ${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            echo 'Pipeline completed.'
            // cleanWs() requires node context - remove or move to stage-level post block
        }
    }
}