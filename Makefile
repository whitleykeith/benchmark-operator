# SysArgs
GIT_COMMIT=$(shell git rev-parse HEAD)
BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# Build Args
PUSH_IMAGE?=false
IMAGE_TAG?=latest
IMAGE_REPO?=localhost/benchmark-operator


# Deploy Args
INSTALL_NAMESPACE?=my-ripsaw

# Scale CI Args
ES_SERVER?=
ES_PORT?=
REPORT_RESULTS?=


.PHONY: all
all: print_env build_image


# Build the Operator Image
# If PUSH_IMAGE is true, this target will also push the image
.PHONY: build_image
build_image: 
	@echo "Building Operator Image ${IMAGE_REPO}:${IMAGE_TAG}"
	operator-sdk build ${IMAGE_REPO}:${IMAGE_TAG} --image-builder podman
	
	@if [ "$(PUSH_IMAGE)" = "true" ] ; then echo "Pushing Operator Image ${IMAGE_REPO}:${IMAGE_TAG}"; podman push ${IMAGE_REPO}:${IMAGE_TAG} ; fi


.PHONY: deploy_operator
deploy_operator: deploy_operator_dependencies
	BENCHMARK_OPERATOR_IMAGE=${IMAGE_REPO}:${IMAGE_TAG}
	cat resources/operator.yaml | yq w - 'spec.template.spec.containers.(name==benchmark-operator).image' ${BENCHMARK_OPERATOR_IMAGE} | kubectl apply -f -
	kubectl wait --for=condition=available "deployment/benchmark-operator" -n my-ripsaw --timeout=300s



.PHONY: deploy_operator_dependencies
deploy_operator_dependencies: 
	kubectl apply -f resources/namespace.yaml
	kubectl apply -f deploy
	kubectl apply -f resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
	kubectl -n ${INSTALL_NAMESPACE} get roles
	kubectl -n ${INSTALL_NAMESPACE} get rolebindings
	kubectl -n ${INSTALL_NAMESPACE} get podsecuritypolicies
	kubectl -n ${INSTALL_NAMESPACE} get serviceaccounts
	kubectl -n ${INSTALL_NAMESPACE} get serviceaccount benchmark-operator -o yaml
	kubectl -n ${INSTALL_NAMESPACE} get role benchmark-operator -o yaml
	kubectl -n ${INSTALL_NAMESPACE} get rolebinding benchmark-operator -o yaml
	kubectl -n ${INSTALL_NAMESPACE} get podsecuritypolicy privileged -o yaml




# Print environment variables 
.PHONY: print_env
print_env: 
	@echo "Git Commit: ${GIT_COMMIT}"
	@echo "Build Date: ${BUILD_DATE}"
	@echo "Push Image: ${PUSH_IMAGE}"
	@echo "Image Tag:  ${IMAGE_TAG}"
	@echo "Install Namespace: ${INSTALL_NAMESPACE}"
	@echo "ElasticSearch URL: ${ES_SERVER}"
	@echo "ElasticSearch Port: ${ES_PORT}"