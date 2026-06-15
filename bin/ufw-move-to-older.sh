#!/bin/bash
cat /var/log/ufw.log | sudo tee -a /var/log/ufw.log.1
echo -n "" | sudo tee /var/log/ufw.log
