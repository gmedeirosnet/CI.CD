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
                    sh '''
                        echo "=== Checking for Maven ==="

                        # Check common Maven installation locations
                        MAVEN_PATHS=(
                            "/opt/maven/bin/mvn"
                            "/usr/share/maven/bin/mvn"
                            "/usr/local/maven/bin/mvn"
                            "$(which mvn 2>/dev/null)"
                        )

                        MAVEN_FOUND=false
                        for MVN_PATH in "${MAVEN_PATHS[@]}"; do
                            if [ -x "$MVN_PATH" ]; then
                                echo "Found Maven at: $MVN_PATH"
                                export PATH="$(dirname $MVN_PATH):$PATH"
                                MAVEN_FOUND=true
                                break
                            fi
                        done

                        if [ "$MAVEN_FOUND" = false ]; then
                            echo "Maven not found. Setting up Maven Wrapper..."
                            if [ ! -f "mvnw" ]; then
                                curl -o mvnw https://raw.githubusercontent.com/takari/maven-wrapper/master/mvnw
                                chmod +x mvnw
                                mkdir -p .mvn/wrapper
                                curl -o .mvn/wrapper/maven-wrapper.jar https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.2.0/maven-wrapper-3.2.0.jar
                                curl -o .mvn/wrapper/maven-wrapper.properties https://raw.githubusercontent.com/takari/maven-wrapper/master/.mvn/wrapper/maven-wrapper.properties
                            fi
                            alias mvn='./mvnw'
                        fi

                        # Verify Maven is working
                        if command -v mvn &> /dev/null; then
                            mvn --version
                        else
                            ./mvnw --version
                        fi
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                echo "Building version ${IMAGE_TAG}"
            }
        }

        stage('Maven Build') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh './mvnw test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh './mvnw sonar:sonar'
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
                sh """
                    cd helm-charts/cicd-demo
                    sed -i '' 's/tag: .*/tag: "${IMAGE_TAG}"/' values.yaml
                    git add values.yaml
                    git commit -m "Update image tag to ${IMAGE_TAG}" || true
                    git push origin main || true
                """
            }
        }

        stage('Deploy with ArgoCD') {
            steps {
                sh """
                    argocd app create cicd-demo \
                        --repo https://github.com/yourusername/cicd-demo.git \
                        --path helm-charts/cicd-demo \
                        --dest-server https://kubernetes.default.svc \
                        --dest-namespace ${NAMESPACE} \
                        --sync-policy automated \
                        --auto-prune \
                        --self-heal \
                        || true

                    argocd app sync cicd-demo
                    argocd app wait cicd-demo --timeout 300
                """
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