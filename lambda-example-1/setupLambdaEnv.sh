#!/bin/bash
VIRTUAL_ENV=venv_lambda
rm -rf ${VIRTUAL_ENV}
virtualenv -p /usr/bin/python2.7 ${VIRTUAL_ENV}
source ${VIRTUAL_ENV}/bin/activate
pip install -r requirements.txt
deactivate
