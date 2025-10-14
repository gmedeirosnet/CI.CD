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
                    // Use system mvn if available, otherwise use wrapper
                    sh '''
                        if command -v mvn >/dev/null 2>&1; then
                            mvn clean package -DskipTests
                        else
                            ./mvnw clean package -DskipTests
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

        stage('Ensure Source Present') {
            steps {
                script {
                    echo 'Checking that repository source (src/) is present in the workspace...'
                    // Print diagnostics that help identify sparse/lightweight checkout issues
                    sh '''#!/bin/bash
                        echo "PWD: $(pwd)"
                        echo "Workspace listing (top-level):"
                        ls -la || true
                        echo ".git exists?:"; [ -d .git ] && echo yes || echo no
                        echo "Git files (if repo present):"
                        if [ -d .git ]; then
                            git rev-parse --show-toplevel || true
                            git ls-files | sed -n '1,200p' || true
                            echo "Shallow repo?:"; git rev-parse --is-shallow-repository || true
                            if [ -f .git/info/sparse-checkout ]; then
                                echo "Sparse-checkout rules:"; cat .git/info/sparse-checkout || true
                            fi
                        fi
                    '''

                    // If src doesn't exist, attempt a robust full checkout using GitSCM (wipe workspace + no shallow)
                    if (!fileExists('src')) {
                        echo 'src/ not found — attempting a full wipe + Git checkout using GitSCM...'
                        // Try a forced checkout via the scm binding with WipeWorkspace and non-shallow clone
                        try {
                            checkout([$class: 'GitSCM', branches: scm.branches, userRemoteConfigs: scm.userRemoteConfigs,
                                      doGenerateSubmoduleConfigurations: false,
                                      extensions: [
                                          [$class: 'WipeWorkspace'],
                                          [$class: 'CleanBeforeCheckout'],
                                          [$class: 'CloneOption', noTags: false, shallow: false, depth: 0]
                                      ]
                            ])
                        } catch (err) {
                            echo "GitSCM checkout attempt failed: ${err}"
                        }

                        // Re-run diagnostics
                        sh '''#!/bin/bash
                            echo "Post-checkout listing:"; ls -la || true
                            echo "Listing src/:"; ls -la src || echo "src still missing"
                            if [ -d .git ]; then
                                echo "Post-checkout git ls-files (first 200):"; git ls-files | sed -n '1,200p' || true
                            fi
                        '''

                        // If still missing, as a last resort try a plain git clone into a temporary directory and move files
                        if (!fileExists('src')) {
                            echo 'src still missing after GitSCM checkout. Attempting fallback git clone into tmp folder...'
                            def repoUrl = scm.userRemoteConfigs[0].url
                            sh """#!/bin/bash
                                set -e
                                TMPDIR=$(mktemp -d)
                                echo "Cloning ${repoUrl} into ${TMPDIR} (may require credentials/SSH agent)..."
                                git clone --depth=1 '${repoUrl}' "${TMPDIR}" || true
                                echo "Contents of tmp clone (top-level):"; ls -la "${TMPDIR}" || true
                                # If clone produced a src/ directory, copy into workspace
                                if [ -d "${TMPDIR}/src" ]; then
                                    cp -a "${TMPDIR}/." . || true
                                    echo "Copied files from temporary clone into workspace"
                                else
                                    echo "Fallback clone did not produce src/ — clone may have failed or repo requires auth"
                                fi
                                rm -rf "${TMPDIR}"
                            """
                        }

                        // Final check
                        if (fileExists('src')) {
                            echo 'Source present after fallback — continuing.'
                        } else {
                            echo "ALERT: src/ still not present. Please disable 'Lightweight checkout' or adjust branch source settings in Jenkins job configuration and re-run the pipeline."
                            // Fail the build so user can take action, but include helpful hint
                            error("Missing source directory 'src' in workspace — cannot build Docker image")
                        }
                    } else {
                        echo 'src/ already present — proceeding.'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Debug: show workspace and confirm src exists in build context
                    sh '''
                        echo "WORKSPACE=${WORKSPACE:-(not set)}"
                        pwd
                        echo "Listing current directory:"
                        ls -la || true
                        echo "Listing src/:"
                        ls -la src || echo "src not found"
                        echo "Git top-level and status (if available):"
                        git rev-parse --show-toplevel || true
                        git status --porcelain || true
                    '''

                    // Build the image (run after debugging output)
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