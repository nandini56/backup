#/bin/bash

###### HELP #############
## yum install vsftpd
## yum install mailx
## yum install sshpass
## yum install rsync
######## HELP ###########


touch /SAP/data_in/file1_E1234_${DATE}.pdf
touch /SAP/data_in/file2_E5678_${DATE}.png
touch /SAP/data_in/nandini_${DATE}.jpeg
touch /SAP/data_in/u8_E1221_$(date +%Y%m%d%H%M%S).pdf
touch /SAP/data_in/nup_${DATE}.pdf
touch /SAP/data_in/E99999_file5_${DATE}.pdf
touch /SAP/data_in/E67_invoice_${DATE}.pdf
touch /SAP/data_in/E9_invoice_${DATE}.pdf
touch /SAP/data_in/E998768_invoice_${DATE}.pdf

# created a separate variable file
echo "Calling variable file..."

# call the variable file in the backup script
source /root/backup/variable.txt

# Check previous script is running or not
echo "Check if previous script is running"
script_name=$(basename -- "$0")

if pidof -x "$script_name" -o $$ >/dev/null; then
  echo "Another instance of this script is already running"
  TRANSFER_STATUS="FAILED --"
  REASON="Another script is running"

  ## Sending mail
  echo "## Sending Failed mail"

  # call the mail script file
  source /root/backup/mail.sh

else
  echo "No instance of this script is running. Continuing with the script"
fi

# Check if the destination server is reachable
echo "Check if the remote is reachable"
if ping -c 1 "${HOST}" >/dev/null 2>&1; then
  echo "Server is reachable. Proceeding with backup."
  TRANSFER_STATUS="SUCCESS --"
else
  echo "Server is not reachable. Backup will not be performed."
  TRANSFER_STATUS="FAILED --"
  REASON="Server is not reachable"

  ## Sending mail
  echo "## Sending Failed mail"
  # call the mail script file
  source /root/backup/mail.sh
  exit 1
fi

# Create the reports directory if it doesn't exist
echo "Check if reports directory exists"
if [ ! -d "${REPORT_DIR}" ]; then
  echo "Reports directory does not exist. Creating directory."
  mkdir -p "${REPORT_DIR}"
else
  echo "Reports directory already exists."
fi

# Check if data_in directory exists
echo "Check if data_in directory exists"
if [ ! -d "${DATA_IN_DIR}" ]; then
  echo "data_in directory does not exist. Creating directory."
  mkdir -p "${DATA_IN_DIR}"
else
  echo "data_in directory already exists."
fi

# Check if invoice_repo directory exists
echo "Check if invoice_repo directory exists"
if [ ! -d "${INVOICE_REPO_DIR}" ]; then
  echo "invoice_repo directory does not exist. Creating directory."
  mkdir -p "${INVOICE_REPO_DIR}"
else
  echo "invoice_repo directory already exists."
fi

# Check for data in data_in folder
echo "Check for data in data_in folder"
if [ ! "$(ls -A ${DATA_IN_DIR})" ]; then
  echo "No data found in data_in folder. Exiting script."
  TRANSFER_STATUS="FAILED --"
  REASON="No data found to tranfer"

  echo "## Sending Failed mail"

  # call the mail script file
  source /root/backup/mail.sh
  exit 1
else
  echo "Data found in data_in folder. Continuing with the script."
  TRANSFER_STATUS="SUCCESS --"
fi

 
# Upload file to remote server
echo "Upload file to remote server"
sshpass -p ${PASSWORD} rsync -avz -e "ssh -o StrictHostKeyChecking=no -p 22" ${DATA_IN_DIR}/* "${USER}@${HOST}:${DESTINATION}"


# Move files to respective employee ID folders
echo "Move files to respective employee ID folders"
cd "${DATA_IN_DIR}"
find "${DATA_IN_DIR}" -type f \( -iname "*.pdf" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | while IIFS= read -r -d '' file; do


# Extract employee ID and date from the file name
  emp_id=$(basename "$file" | grep -o -E "E[0-9]{1,6}")


  if [[ -n "$emp_id" ]]; then
    # Create the employee ID folder if it doesn't exist
    mkdir -p "${INVOICE_REPO_DIR}/${emp_id}"

    # Move the file to the respective employee ID folder
    mv "$file" "${INVOICE_REPO_DIR}/${emp_id}/"

  else
    # If the file does not match the employee ID pattern, move to no_emp folder
    mkdir -p "${INVOICE_REPO_DIR}/no_emp_id/"
    mv "$file" "${INVOICE_REPO_DIR}/no_emp_id/"
  fi
done

## Generate report in CSV format
echo "Generate report in CSV format"
echo "File Name,destination path,Transfer Status,Date" > "$REPORT_FILE"
find "${INVOICE_REPO_DIR}" -type f \( -iname "*.pdf" -o -iname "*.jpeg" -o -iname "*.doc" \) -printf '%f,%h,Success,%TY-%Tm-%Td-%TH:%TM:%TS\n' >> "$REPORT_FILE"

if [ ! -f "$COMPLETE_REPORT" ]; then
  # If $COMPLETE_REPORT file doesn't exist, copy the daily report file
  cp "$REPORT_FILE" "$COMPLETE_REPORT"
else
  # Append the data from the daily report file (excluding the heading) to the consolidated report file
  tail -n +2 "$REPORT_FILE" >> "$COMPLETE_REPORT"
fi

echo "CSV report generated successfully."

# Check transfer status
echo "Checking transfer status"

if [ $? -eq 0 ]; then
  echo "Transfer successful"
  TRANSFER_STATUS="SUCCESS --"
  REASON="Transfer successful"
  echo "## Sending Success mail"
  # call the mail script file
  source /root/backup/mail.sh

else
  echo "Transfer failed: rsync error"

  TRANSFER_STATUS="FAILED --"
  REASON="Transfer failed"
  # Sending mail
  echo "## Sending Failed mail"

  # calling mail script file
  source /root/backup/mail.sh
  exit 1
fi
