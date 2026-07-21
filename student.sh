#!/bin/bash
# Student Management System - PART 1
# Features: Login, Add Student, View Students, Duplicate ID check,
#           Phone/Age validation, Date & Time stamp, Colorful menu, Logging

# ---------------------------- CONFIG / FILES --------------------------------
DB_FILE="students.txt"
LOG_FILE="logs.txt"
BACKUP_FILE="backup.txt"
PASSWORD="linux123"          # change this to whatever password you want

# ---------------------------- COLOR CODES ------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'                 # No Color / reset

# Make sure the data files exist so grep/cat don't error on first run
touch "$DB_FILE" "$LOG_FILE"

# ---------------------------- LOGGING FUNCTION -------------------------------
# Every important action gets written to logs.txt with a timestamp
log_action() {
    local action="$1"
    local time_now
    time_now=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$time_now] $action" >> "$LOG_FILE"
}

# ---------------------------- LOGIN FUNCTION ---------------------------------
login() {
    local attempts=3
    while [ $attempts -gt 0 ]; do
        read -s -p "Enter Password: " input_pass
        echo
        if [ "$input_pass" == "$PASSWORD" ]; then
            echo -e "${GREEN}Login Successful!${NC}"
            log_action "LOGIN SUCCESS"
            sleep 1
            return 0
        else
            attempts=$((attempts - 1))
            echo -e "${RED}Wrong password. Attempts left: $attempts${NC}"
        fi
    done
    echo -e "${RED}Too many failed attempts. Exiting...${NC}"
    log_action "LOGIN FAILED - script exited"
    exit 1
}

# ---------------------------- VALIDATION FUNCTIONS ---------------------------
# Phone must be exactly 10 digits
validate_phone() {
    local phone="$1"
    if [[ "$phone" =~ ^[0-9]{10}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Age must be a number between 15 and 60 (reasonable student age range)
validate_age() {
    local age="$1"
    if [[ "$age" =~ ^[0-9]+$ ]] && [ "$age" -ge 15 ] && [ "$age" -le 60 ]; then
        return 0
    else
        return 1
    fi
}

# Marks must be a number between 0 and 100
validate_marks() {
    local marks="$1"
    if [[ "$marks" =~ ^[0-9]+$ ]] && [ "$marks" -ge 0 ] && [ "$marks" -le 100 ]; then
        return 0
    else
        return 1
    fi
}

# ---------------------------- GRADE CALCULATION ------------------------------
calculate_grade() {
    local marks="$1"
    if [ "$marks" -ge 90 ]; then echo "A+"
    elif [ "$marks" -ge 80 ]; then echo "A"
    elif [ "$marks" -ge 70 ]; then echo "B"
    elif [ "$marks" -ge 60 ]; then echo "C"
    elif [ "$marks" -ge 50 ]; then echo "D"
    else echo "F"
    fi
}

# ---------------------------- ADD STUDENT ------------------------------------
add_student() {
    echo -e "${CYAN}----- Add New Student -----${NC}"

    read -p "Enter Student ID: " id

    # Duplicate ID check - search field 1 (ID) in the pipe-delimited file
    if grep -q "^$id|" "$DB_FILE"; then
        echo -e "${RED}Error: Student ID $id already exists!${NC}"
        log_action "ADD FAILED - Duplicate ID $id"
        return
    fi

    read -p "Enter Name: " name
    read -p "Enter Age: " age

    if ! validate_age "$age"; then
        echo -e "${RED}Invalid age! Must be a number between 15 and 60.${NC}"
        log_action "ADD FAILED - Invalid age for ID $id"
        return
    fi

    read -p "Enter Course: " course
    read -p "Enter Phone Number: " phone

    if ! validate_phone "$phone"; then
        echo -e "${RED}Invalid phone number! Must be exactly 10 digits.${NC}"
        log_action "ADD FAILED - Invalid phone for ID $id"
        return
    fi

    read -p "Enter Marks (0-100): " marks

    if ! validate_marks "$marks"; then
        echo -e "${RED}Invalid marks! Must be a number between 0 and 100.${NC}"
        log_action "ADD FAILED - Invalid marks for ID $id"
        return
    fi

    grade=$(calculate_grade "$marks")
    date_time=$(date "+%Y-%m-%d %H:%M:%S")

    # Append the record - pipe-delimited, matches the format spec
    echo "$id|$name|$age|$course|$phone|$marks|$grade|$date_time" >> "$DB_FILE"

    echo -e "${GREEN}Student added successfully! Grade: $grade${NC}"
    log_action "ADD SUCCESS - ID $id, Name $name"
}

# ---------------------------- VIEW STUDENTS ----------------------------------
view_students() {
    echo -e "${CYAN}----- Student Records -----${NC}"

    if [ ! -s "$DB_FILE" ]; then
        echo -e "${YELLOW}No records found.${NC}"
        return
    fi

    printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
        "ID" "Name" "Age" "Course" "Phone" "Marks" "Grade" "Date_Time"
    echo "--------------------------------------------------------------------------------------"

    while IFS='|' read -r id name age course phone marks grade date_time; do
        printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
            "$id" "$name" "$age" "$course" "$phone" "$marks" "$grade" "$date_time"
    done < "$DB_FILE"

    log_action "VIEWED all student records"
}

# ---------------------------- SEARCH BY ID -----------------------------------
search_by_id() {
    read -p "Enter Student ID to search: " sid
    local record
    record=$(grep "^$sid|" "$DB_FILE")

    if [ -z "$record" ]; then
        echo -e "${RED}No student found with ID $sid${NC}"
        log_action "SEARCH BY ID - not found ($sid)"
        return
    fi

    printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
        "ID" "Name" "Age" "Course" "Phone" "Marks" "Grade" "Date_Time"
    echo "--------------------------------------------------------------------------------------"
    IFS='|' read -r id name age course phone marks grade date_time <<< "$record"
    printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
        "$id" "$name" "$age" "$course" "$phone" "$marks" "$grade" "$date_time"

    log_action "SEARCH BY ID - found ($sid)"
}

# ---------------------------- SEARCH BY NAME ---------------------------------
search_by_name() {
    read -p "Enter Name (or part of name) to search: " sname
    # Case-insensitive partial match against the Name field (column 2)
    local matches
    matches=$(awk -F'|' -v name="$sname" 'BEGIN{IGNORECASE=1} $2 ~ name {print}' "$DB_FILE")

    if [ -z "$matches" ]; then
        echo -e "${RED}No student found matching name: $sname${NC}"
        log_action "SEARCH BY NAME - not found ($sname)"
        return
    fi

    printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
        "ID" "Name" "Age" "Course" "Phone" "Marks" "Grade" "Date_Time"
    echo "--------------------------------------------------------------------------------------"
    while IFS='|' read -r id name age course phone marks grade date_time; do
        printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
            "$id" "$name" "$age" "$course" "$phone" "$marks" "$grade" "$date_time"
    done <<< "$matches"

    log_action "SEARCH BY NAME - found match(es) for ($sname)"
}

# ---------------------------- UPDATE STUDENT ---------------------------------
update_student() {
    read -p "Enter Student ID to update: " uid
    local record
    record=$(grep "^$uid|" "$DB_FILE")

    if [ -z "$record" ]; then
        echo -e "${RED}No student found with ID $uid${NC}"
        log_action "UPDATE FAILED - ID not found ($uid)"
        return
    fi

    IFS='|' read -r id name age course phone marks grade date_time <<< "$record"

    echo -e "${YELLOW}Leave a field blank to keep its current value.${NC}"

    read -p "Name [$name]: " new_name
    read -p "Age [$age]: " new_age
    read -p "Course [$course]: " new_course
    read -p "Phone [$phone]: " new_phone
    read -p "Marks [$marks]: " new_marks

    # Use existing value if user just hits Enter
    new_name="${new_name:-$name}"
    new_age="${new_age:-$age}"
    new_course="${new_course:-$course}"
    new_phone="${new_phone:-$phone}"
    new_marks="${new_marks:-$marks}"

    if ! validate_age "$new_age"; then
        echo -e "${RED}Invalid age! Update cancelled.${NC}"
        log_action "UPDATE FAILED - Invalid age ($uid)"
        return
    fi

    if ! validate_phone "$new_phone"; then
        echo -e "${RED}Invalid phone! Update cancelled.${NC}"
        log_action "UPDATE FAILED - Invalid phone ($uid)"
        return
    fi

    if ! validate_marks "$new_marks"; then
        echo -e "${RED}Invalid marks! Update cancelled.${NC}"
        log_action "UPDATE FAILED - Invalid marks ($uid)"
        return
    fi

    new_grade=$(calculate_grade "$new_marks")
    new_date_time=$(date "+%Y-%m-%d %H:%M:%S")
    new_line="$id|$new_name|$new_age|$new_course|$new_phone|$new_marks|$new_grade|$new_date_time"

    # Replace the old line with the new one, in place (awk avoids delimiter
    # conflicts that sed would have since our data itself uses '|')
    awk -F'|' -v id="$id" -v newline="$new_line" \
        'BEGIN{OFS="|"} $1==id {print newline; next} {print}' "$DB_FILE" > "${DB_FILE}.tmp" \
        && mv "${DB_FILE}.tmp" "$DB_FILE"

    echo -e "${GREEN}Student ID $id updated successfully! New Grade: $new_grade${NC}"
    log_action "UPDATE SUCCESS - ID $uid"
}

# ---------------------------- DELETE STUDENT ---------------------------------
delete_student() {
    read -p "Enter Student ID to delete: " did

    if ! grep -q "^$did|" "$DB_FILE"; then
        echo -e "${RED}No student found with ID $did${NC}"
        log_action "DELETE FAILED - ID not found ($did)"
        return
    fi

    read -p "Are you sure you want to delete ID $did? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Delete cancelled.${NC}"
        return
    fi

    awk -F'|' -v id="$did" '$1!=id {print}' "$DB_FILE" > "${DB_FILE}.tmp" && mv "${DB_FILE}.tmp" "$DB_FILE"

    echo -e "${GREEN}Student ID $did deleted successfully.${NC}"
    log_action "DELETE SUCCESS - ID $did"
}

# ---------------------------- COUNT STUDENTS ---------------------------------
count_students() {
    local total
    total=$(wc -l < "$DB_FILE")
    echo -e "${CYAN}Total number of students: $total${NC}"
    log_action "COUNT - total students = $total"
}

# ---------------------------- SORT STUDENTS ----------------------------------
sort_students() {
    echo -e "${CYAN}Sort by:${NC}"
    echo "1. Name (A-Z)"
    echo "2. Marks (High to Low)"
    echo "3. Age (Low to High)"
    read -p "Choose sort option [1-3]: " sort_choice

    local sorted
    case $sort_choice in
        1) sorted=$(sort -t'|' -k2,2 "$DB_FILE") ;;
        2) sorted=$(sort -t'|' -k6,6 -nr "$DB_FILE") ;;
        3) sorted=$(sort -t'|' -k3,3 -n "$DB_FILE") ;;
        *)
            echo -e "${RED}Invalid option.${NC}"
            return
            ;;
    esac

    printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
        "ID" "Name" "Age" "Course" "Phone" "Marks" "Grade" "Date_Time"
    echo "--------------------------------------------------------------------------------------"
    while IFS='|' read -r id name age course phone marks grade date_time; do
        printf "%-6s %-15s %-5s %-10s %-12s %-6s %-6s %-20s\n" \
            "$id" "$name" "$age" "$course" "$phone" "$marks" "$grade" "$date_time"
    done <<< "$sorted"

    log_action "SORTED student list (option $sort_choice)"
}

# ---------------------------- BACKUP DATABASE --------------------------------
backup_database() {
    if [ ! -s "$DB_FILE" ]; then
        echo -e "${YELLOW}Nothing to backup - student database is empty.${NC}"
        log_action "BACKUP SKIPPED - database empty"
        return
    fi

    cp "$DB_FILE" "$BACKUP_FILE"

    local count
    count=$(wc -l < "$BACKUP_FILE")
    echo -e "${GREEN}Backup successful! $count record(s) saved to $BACKUP_FILE${NC}"
    log_action "BACKUP SUCCESS - $count record(s) backed up"
}

# ---------------------------- RESTORE DATABASE -------------------------------
restore_database() {
    if [ ! -s "$BACKUP_FILE" ]; then
        echo -e "${RED}No backup found! Run Backup Database first.${NC}"
        log_action "RESTORE FAILED - no backup file found"
        return
    fi

    # Warn the user since this overwrites current data
    echo -e "${YELLOW}WARNING: This will overwrite the current student database"
    echo -e "with the contents of $BACKUP_FILE.${NC}"
    read -p "Are you sure you want to restore? (y/n): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Restore cancelled.${NC}"
        log_action "RESTORE CANCELLED by user"
        return
    fi

    cp "$BACKUP_FILE" "$DB_FILE"

    local count
    count=$(wc -l < "$DB_FILE")
    echo -e "${GREEN}Restore successful! $count record(s) restored from backup.${NC}"
    log_action "RESTORE SUCCESS - $count record(s) restored"
}

# ---------------------------- MAIN MENU --------------------------------------
main_menu() {
    while true; do
        echo -e "\n${BLUE}==================================${NC}"
        echo -e "${BLUE}   STUDENT MANAGEMENT SYSTEM${NC}"
        echo -e "${BLUE}==================================${NC}"
        echo -e "${YELLOW}1.${NC} Add Student"
        echo -e "${YELLOW}2.${NC} View Students"
        echo -e "${YELLOW}3.${NC} Search by ID"
        echo -e "${YELLOW}4.${NC} Search by Name"
        echo -e "${YELLOW}5.${NC} Update Student"
        echo -e "${YELLOW}6.${NC} Delete Student"
        echo -e "${YELLOW}7.${NC} Count Students"
        echo -e "${YELLOW}8.${NC} Sort Students"
        echo -e "${YELLOW}9.${NC} Backup Database"
        echo -e "${YELLOW}10.${NC} Restore Database"
        echo -e "${YELLOW}11.${NC} Exit"
        echo -e "${BLUE}==================================${NC}"
        read -p "Choose an option [1-11]: " choice

        case $choice in
            1) add_student ;;
            2) view_students ;;
            3) search_by_id ;;
            4) search_by_name ;;
            5) update_student ;;
            6) delete_student ;;
            7) count_students ;;
            8) sort_students ;;
            9) backup_database ;;
           10) restore_database ;;
           11)
                echo -e "${GREEN}Goodbye!${NC}"
                log_action "SCRIPT EXITED normally"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Try again.${NC}"
                ;;
        esac
    done
}

# ---------------------------- SCRIPT ENTRY POINT -----------------------------
login
main_menu
