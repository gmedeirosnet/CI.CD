pipeline {
    agent any

    environment {
        // Harbor - Load from credentials or environment
        HARBOR_REGISTRY = "${env.HARBOR_REGISTRY ?: 'localhost:8082'}"
        HARBOR_PROJECT = "${env.HARBOR_PROJECT ?: 'cicd-demo'}"
        IMAGE_NAME = 'app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        // SonarQube - Load from environment
        SONAR_HOST = "${env.SONAR_HOST ?: 'http://sonarqube:9000'}"

        // Kubernetes - Load from environment
        // KUBECONFIG = credentials('kubeconfig')  // Commented out - configure in Jenkins Credentials if needed
        NAMESPACE = "${env.KUBE_NAMESPACE ?: 'app-demo'}"

        // Kind Cluster - For Mac Docker Desktop image loading
        KIND_CLUSTER_NAME = "${env.KIND_CLUSTER_NAME ?: 'app-demo'}"
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

        stage('Load Image into Kind') {
            steps {
                script {
                    sh """
                        echo "=== Loading images into Kind cluster for Mac Docker Desktop ==="

                        # Kind cluster name
                        KIND_CLUSTER="\${KIND_CLUSTER_NAME:-app-demo}"

                        # Check if Kind cluster exists
                        if ! kind get clusters | grep -q "\${KIND_CLUSTER}"; then
                            echo "WARNING: Kind cluster '\${KIND_CLUSTER}' not found. Skipping image load."
                            echo "Available clusters:"
                            kind get clusters || echo "No Kind clusters found"
                            exit 0
                        fi

                        echo "Found Kind cluster: \${KIND_CLUSTER}"

                        # Tag images with host.docker.internal for Kind
                        echo "Tagging images for Kind..."
                        docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                                   host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest \
                                   host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:latest

                        # Load versioned image into Kind
                        echo "Loading image with tag ${IMAGE_TAG} into Kind..."
                        kind load docker-image host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} \
                             --name "\${KIND_CLUSTER}"

                        # Load latest tag into Kind
                        echo "Loading latest tag into Kind..."
                        kind load docker-image host.docker.internal:8082/${HARBOR_PROJECT}/${IMAGE_NAME}:latest \
                             --name "\${KIND_CLUSTER}"

                        echo "✅ Images successfully loaded into Kind cluster"

                        # Verify images are loaded
                        echo "Verifying images in Kind nodes..."
                        docker exec \${KIND_CLUSTER}-control-plane crictl images | grep ${HARBOR_PROJECT}/${IMAGE_NAME} || echo "Image verification: check manually"
                    """
                }
            }
        }

        stage('Update Helm Chart') {
            steps {
                script {
                    sh """
                        cd helm-charts/cicd-demo
                        sed -i 's/tag: .*/tag: "${IMAGE_TAG}"/' values.yaml
                        cat values.yaml | grep tag:
                    """
                }
            }
        }

        stage('Prepare Namespace') {
            steps {
                script {
                    sh """
                        echo "=== Ensuring namespace ${NAMESPACE} exists ==="

                        # Kind cluster name
                        KIND_CLUSTER="\${KIND_CLUSTER_NAME:-app-demo}"

                        # Check if Kind cluster exists
                        if ! kind get clusters | grep -q "\${KIND_CLUSTER}"; then
                            echo "WARNING: Kind cluster '\${KIND_CLUSTER}' not found. Skipping namespace preparation."
                            exit 0
                        fi

                        # Create namespace if it doesn't exist (using docker exec to run kubectl in Kind control plane)
                        docker exec \${KIND_CLUSTER}-control-plane kubectl create namespace ${NAMESPACE} 2>/dev/null || \
                            echo "Namespace ${NAMESPACE} already exists or created"

                        # Create Harbor registry secret in the namespace
                        docker exec \${KIND_CLUSTER}-control-plane kubectl create secret docker-registry harbor-cred \
                            --docker-server=host.docker.internal:8082 \
                            --docker-username=admin \
                            --docker-password=Harbor12345 \
                            --namespace=${NAMESPACE} \
                            2>/dev/null || echo "Secret harbor-cred already exists or created"

                        echo "✅ Namespace ${NAMESPACE} is ready"
                        docker exec \${KIND_CLUSTER}-control-plane kubectl get namespace ${NAMESPACE}
                    """
                }
            }
        }        stage('Deploy with ArgoCD') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'argocd-credentials',
                                                     usernameVariable: 'ARGOCD_USER',
                                                     passwordVariable: 'ARGOCD_PASS')]) {
                        sh """
                            # Set ArgoCD server - use host.docker.internal to reach host from container
                            export ARGOCD_SERVER='host.docker.internal:8090'

                            # Login to ArgoCD
                            argocd login \${ARGOCD_SERVER} \
                                --username \${ARGOCD_USER} \
                                --password \${ARGOCD_PASS} \
                                --grpc-web \
                                --insecure

                            # Create ArgoCD application if it doesn't exist
                            argocd app create cicd-demo \
                                --repo https://github.com/gmedeirosnet/CI.CD.git \
                                --path helm-charts/cicd-demo \
                                --dest-server https://kubernetes.default.svc \
                                --dest-namespace ${NAMESPACE} \
                                --sync-policy automated \
                                --auto-prune \
                                --self-heal \
                                --grpc-web \
                                --insecure \
                                2>/dev/null || echo "ArgoCD app already exists"

                            # Sync and wait for deployment
                            argocd app sync cicd-demo --timeout 300 --grpc-web --insecure
                            argocd app wait cicd-demo --timeout 300 --grpc-web --insecure

                            # Show application status
                            argocd app get cicd-demo --grpc-web --insecure
                        """
                    }
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
                script {
                    sh """
                        # Kind cluster name
                        KIND_CLUSTER="\${KIND_CLUSTER_NAME:-app-demo}"

                        # Check if Kind cluster exists
                        if ! kind get clusters | grep -q "\${KIND_CLUSTER}"; then
                            echo "WARNING: Kind cluster '\${KIND_CLUSTER}' not found. Skipping verification."
                            exit 0
                        fi

                        echo "=== Verifying deployment in namespace ${NAMESPACE} ==="
                        docker exec \${KIND_CLUSTER}-control-plane kubectl get pods -n ${NAMESPACE}
                        docker exec \${KIND_CLUSTER}-control-plane kubectl get svc -n ${NAMESPACE}
                    """
                }
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