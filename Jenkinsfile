/*
    This is an example pipeline that implement full CI/CD for a simple static web site packed in a Docker image.
    The pipeline is made up of 6 main steps
    1. Git clone and setup
    2. Build and local tests
    3. Publish Docker and Helm
    4. Deploy to dev and test
    5. Deploy to staging and test
    6. Optionally deploy to production and test
 */

/*
    Build a docker image
*/
def buildDockerImage(image_name, image_id, src_dir) {
        echo "Building the Web Docker Image"
        sh "docker build -t ${image_name} -f ${WORKSPACE}/${src_dir}/Dockerfile ${WORKSPACE}/${src_dir}"
}

/*
    Publish a docker image
*/
def publishDockerImage(image_name) {
	echo "Logging to aws ecr"
	sh "aws ecr get-login --no-include-email --region us-east-1 | sh"
	echo "Tagging and pushing the Web Docker Image"                
	sh "docker tag ${image_name} ${DOCKER_REG}/${image_name}:${DOCKER_TAG}"
	sh "docker push ${DOCKER_REG}/${image_name}"
}


/*
    This is the main pipeline section with the stages of the CI/CD
 */
pipeline {

    options {
        // Build auto timeout
        timeout(time: 60, unit: 'MINUTES')
    }

    // Some global default variables
    environment {
        API_IMAGE_NAME = 'top-api'
        WEB_IMAGE_NAME = 'top-web'
	WEB_SRC_DIR = "/src/web"
	API_SRC_DIR = "/src/api"
        DOCKER_TAG = "stable"
        DOCKER_REG = "949221880207.dkr.ecr.us-east-1.amazonaws.com"
	DEPLOY_PROD = false
    }

    parameters {
        string (name: 'GIT_BRANCH',           defaultValue: 'master',  description: 'Git branch to build')
        booleanParam (name: 'DEPLOY_TO_PROD', defaultValue: false,     description: 'If build and tests are good, proceed and deploy to production without manual approval')

    }

    //all is built and run from the master
    agent { node { label 'master' } }

    // Pipeline stages
    stages {

        ////////// Step 1 //////////
        stage('Git clone and setup') {
            steps {
                echo "Check out code"
		checkout scm

                // Validate kubectl
                sh "kubectl cluster-info"

                // Init helm client
                sh "helm init"

		//clean docker
		sh "docker system prune -a -f"

                // Define a unique name for the tests container and helm release
                script {
                    branch = GIT_BRANCH.replaceAll('/', '-').replaceAll('\\*', '-')
                    WEB_ID = "${WEB_IMAGE_NAME}-${DOCKER_TAG}-${branch}"
                    API_ID = "${API_IMAGE_NAME}-${DOCKER_TAG}-${branch}"

                    echo "Global web Id set to ${WEB_ID}"
                    echo "Global api Id set to ${API_ID}"
                }
            }
        }

        ////////// Step 2 //////////
        stage('Build Docker Images') {
		parallel {
			stage('Build web image') {
				steps {
					buildDockerImage("${WEB_IMAGE_NAME}","${WEB_ID}","${WEB_SRC_DIR}")
				}
			}
			stage('Build api image') {
				steps {
					buildDockerImage("${API_IMAGE_NAME}","${API_ID}","${API_SRC_DIR}")
				}
			}
		}
        }

	////////// Step 3 //////////
        stage('Publish Docker Images') {
		parallel {
			stage('Publish web image') {
				steps {
					publishDockerImage("${WEB_IMAGE_NAME}")
				}
			}
			stage('Publish api image') {
				steps {
					publishDockerImage("${API_IMAGE_NAME}")
				}
			}
		}
        }

	////////// Step 4 //////////
	stage('Deploying to test') {
            steps {
		script {
			namespace="test"
			echo "Updating helm charts"
			sh "helm upgrade --install --namespace ${namespace} web-test ${WORKSPACE}/helm/web -f ${WORKSPACE}/helm/web/values_test.yaml"
			sh "helm upgrade --install --namespace ${namespace} api-test ${WORKSPACE}/helm/api -f ${WORKSPACE}/helm/api/values_test.yaml"
			sh "sleep 30"
		}
            }
        }

	////////// Step 5 //////////
	stage('Testing in test') {
            steps {
		echo "Testing in test"
		sh "python ${WORKSPACE}/src/jenkins/tests/web_test.py"
            }
	}

        // Waif for user manual approval, or proceed automatically if DEPLOY_TO_PROD is true
        stage('Go for Production?') {
            when {
                allOf {
                    environment name: 'GIT_BRANCH', value: 'master'
                    environment name: 'DEPLOY_TO_PROD', value: 'false'
                }
            }

            steps {
                // Prevent any older builds from deploying to production
                milestone(1)
                input 'Proceed and deploy to Production?'
                milestone(2)

                script {
                    DEPLOY_PROD = true
                }
            }
        }

	////////// Step 6 //////////
	stage('Deploying to Production') {
	    when {
                anyOf {
                    expression { DEPLOY_PROD == true }
                    environment name: 'DEPLOY_TO_PROD', value: 'true'
                }
            }
            steps {
		script {
                	DEPLOY_PROD = true
			echo "Updating helm charts"
			sh "helm upgrade --install web ${WORKSPACE}/helm/web"
			sh "helm upgrade --install api ${WORKSPACE}/helm/api"
			sh "sleep 30"
		}
            }
        }

	////////// Step 7 //////////
	stage('Testing in Production') {
            when {
                expression { DEPLOY_PROD == true }
            }
            steps {
		echo "Testing in Production"
		sh "python ${WORKSPACE}/src/jenkins/tests/web_prod.py"
            }
        }
   }
}

