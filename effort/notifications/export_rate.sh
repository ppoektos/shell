#!/bin/bash
#Id=30041072

shopt -s extglob
opo="UA employees"
rmi="UA employees"
override_users='@(opo|rmi)'
override_projects="30041075"

echo "Override users: $override_users."
echo "Override projects: $override_projects."

calc () { awk "BEGIN { print $*}"; }

ActiveProjects=$(curl -snk https://<CONFLUENCE_HOST>/rest/api/content/<PAGE_ID_PROJECTS>?expand=body.storage \
                | python -mjson.tool | grep -oE '[0-9]{8} - [a-zA-Z0-9 ]*')

#ActiveProjects="30041075 - LineDock Unit Development"

while read -r Project; do
    Id=${Project:0:8}
    lenght=${#Project}
    name=${Project:11:$lenght}
    echo "Parent is $name."

    parent=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
            "use <REDMINE_DB>; SELECT id FROM projects WHERE name LIKE '%$Id%' \
            AND projects.status = '1' AND projects.parent_id is NULL;")

    subprojects=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
                "use <REDMINE_DB>; SELECT id FROM projects WHERE parent_id = '$parent'"`)

    echo "Sub projects IDs are ${subprojects[@]}."

    for project in $parent ${subprojects[@]}; do

        project_name=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                       "use <REDMINE_DB>; SELECT name FROM projects \
                        WHERE projects.id = '$project';")

        versions=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
                  "use <REDMINE_DB>; SELECT versions.id FROM versions \
                  WHERE versions.project_id = '$project';"`)

        echo " $project_name"

		for version in ${versions[@]}; do
			uae=0; uaj=0; dk=0;
			unset issues_per_version
			version_name=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                          "use <REDMINE_DB>; SELECT name FROM versions WHERE id = '$version';")

			issues_per_version+=(`mysql --login-path=<DB_LOGIN_PATH> -Nse \
                                "use <REDMINE_DB>; SELECT id FROM issues \
                                WHERE issues.fixed_version_id = '$version' \
                                AND issues.project_id = '$project';"`)

            if [ -z "$issues_per_version" ]; then continue; fi
            echo " - $version_name:"

            #printf '%s, ' "${issues_per_version[@]}" | sed 's/, $//'

            while read user time; do

			     user_name=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                            "use <REDMINE_DB>; SELECT login FROM users \
                            WHERE id = '$user';")

                 if echo "$override_projects" | grep -q $Id; then
                    case $user_name in
                        $override_users) eval user_rate="$"$user_name
                                         echo "Overrided $user_name cost to $user_rate"
                                        ;;
                    esac
                    else
                    user_rate=$(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                               "use <REDMINE_DB>; SELECT custom_values.value FROM custom_values \
                                WHERE custom_values.custom_field_id = '44' \
                                AND custom_values.customized_id = '$user';")
                 fi

                 echo "user: $user_name, time: $time, rate: $user_rate"

                case "$user_rate" in
                    "UA employees") uae=$(calc $uae+$time)
                    ;;
                    "UA junior employees") uaj=$(calc $uaj+$time)
                    ;;
                    "DK employees") dk=$(calc $dk+$time)
                    ;;
                esac

            done < <(mysql --login-path=<DB_LOGIN_PATH> -Nse \
                    "use <REDMINE_DB>; SELECT user_id, ROUND(time_entries.hours, 2) FROM time_entries \
                    WHERE issue_id IN ($(printf '%s, ' "${issues_per_version[@]}" | sed 's/, $//')) \
                    AND month(spent_on) = '02' AND year(spent_on) = '2018' ;")

            echo "  UAE: $uae hours, UAJ: $uaj hours, DK: $dk hours."

            #sleep 1

        done
    echo "-----------------------------------"
    unset versions
    unset subprojects
    done
echo "######################################"
done <<< "$ActiveProjects"
