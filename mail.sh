#!/bin/bash


## Sending mail
source /root/backup/variable.txt

echo -e "$email_body" | mailx -v -s "$email_subject" -a "$REPORT_FILE" \
-S smtp-auth=login \
-S smtp-use-starttls \
-S nss-config-dir=~/.certs \
-S smtp=${SMTP_SERVER}:${SMTP_PORT} \
-S from="${FROM_EMAIL}" \
-S smtp-auth-user="${EMAIL_AUTHUSER}" \
-S smtp-auth-password="${EMAIL_AUTHPWD}" \
-S ssl-verify=ignore \
${TO_EMAIL} 


