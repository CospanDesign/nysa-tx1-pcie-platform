
PWD=$(shell pwd)
MODULEDIR := $(PWD)/src
RULES_FILE=61-nysa-pcie.rules

all: MODULE

test:
	@printf "Rules: %s\n" $(RULES)

MODULE:
	make -C $(MODULEDIR)

instrules:
	sudo cp rules/${RULES_FILE} /etc/udev/rules.d/
	sudo udevadm control --reload

install: instrules
	@printf "Installing Driver"
	make -C $(MODULEDIR) install

rmrules:
	sudo rm /etc/udev/rules.d/${RULES_FILE}

remove:
	make -C $(MODULEDIR) remove
	sudo rm /etc/udev/rules.d/${RULES_FILE}

clean:
	make -C $(MODULEDIR) clean

