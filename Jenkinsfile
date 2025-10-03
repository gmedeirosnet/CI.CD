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
        stage('Setup Environment') {
            steps {
                script {
                    sh '''
                        echo "Checking for required tools..."

                        # Check if Maven is installed
                        if ! command -v mvn &> /dev/null; then
                            echo "Maven not found. Installing Maven..."
                            apt-get update
                            apt-get install -y maven
                        else
                            echo "Maven is already installed: $(mvn --version | head -n 1)"
                        fi

                        # Check if Java is installed
                        if ! command -v java &> /dev/null; then
                            echo "Java not found. Installing OpenJDK 21..."
                            apt-get install -y openjdk-21-jdk
                        else
                            echo "Java is already installed: $(java -version 2>&1 | head -n 1)"
                        fi

                        # Display versions
                        echo "=== Environment Setup Complete ==="
                        mvn --version
                        java -version
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
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test'
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
                    sh 'mvn sonar:sonar'
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