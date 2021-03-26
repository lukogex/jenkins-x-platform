CHART_REPO := http://chartmuseum.devinfra.xxxlgroup.com 
NAME := jenkins-x
OS := $(shell uname)
HELM := helm

init:
	$(HELM) init --client-only

setup: init
	$(HELM) repo add jx http://chartmuseum.jenkins-x.io
	$(HELM) repo add incubator https://charts.helm.sh/incubator
	$(HELM) repo add stable https://charts.helm.sh/stable
	$(HELM) repo add monocular https://helm.github.io/monocular

build: setup clean
	$(HELM) dependency build jenkins-x-platform
	$(HELM) lint jenkins-x-platform

lint:
	$(HELM) dependency build jenkins-x-platform
	$(HELM) lint jenkins-x-platform

install: clean setup build
	$(HELM) upgrade --debug --install $(NAME) jenkins-x-platform

apply: build
	cd jenkins-x-platform && jx step helm apply $(NAME) .

upgrade: clean setup build
	$(HELM) upgrade --debug --install $(NAME) jenkins-x-platform

delete:
	$(HELM) delete --purge $(NAME)

clean: 
	rm -rf jenkins-x-platform/charts
	rm -rf jenkins-x-platform/${NAME}*.tgz
	rm -rf jenkins-x-platform/requirements.lock

release: setup clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" jenkins-x-platform/Chart.yaml
else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" jenkins-x-platform/Chart.yaml
else
	exit -1
endif
	$(HELM) package jenkins-x-platform
	curl --fail -u $(CHARTMUSEUM_USER):$(CHARTMUSEUM_PASS) --data-binary "@$(NAME)-platform-$(VERSION).tgz" $(CHART_REPO)/api/charts
	helm repo add jenkins-x https://storage.googleapis.com/chartmuseum.jenkins-x.io
	echo "we have the following remote helm repos:"	
	helm repo list
	helm repo update
	rm -rf ${NAME}*.tgz
	# jx step changelog  --verbose --version ${VERSION} --rev ${PULL_BASE_SHA}
	# jx step create pr make --name CHART_VERSION --version $(VERSION) --repo https://github.com/jenkins-x/cloud-environments.git
	# jx step create pr regex --regex "JX_PLATFORM_VERSION=(.*)" --version $(VERSION) --files build.sh --repo https://github.com/jenkins-x/cloud-environments.git
