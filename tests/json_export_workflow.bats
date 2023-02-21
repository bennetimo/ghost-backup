#!/usr/bin/env bats



@test "Don't call function to create cookie when -J is passed" {
	run ./backup.sh -J
	[[ $output =~ '-J set: excluding ghost json in backup' ]]
	[[ ! $output =~ '...Retrieving ghost session cookie for user' ]]
}

@test "Function to create cookie is called when JSON backup is enabled" {
		run ./backup.sh
	[[ ! $output =~ '-J set: excluding ghost json in backup' ]]
	[[ $output =~ '...Retrieving ghost session cookie for user' ]]
}

@test "Function to create cookie is called when restoring JSON file" {
	run ./restore.sh -f backup-ghost_20230220-1713.json
	[[ $output =~ '...Retrieving ghost session cookie for user' ]]
}