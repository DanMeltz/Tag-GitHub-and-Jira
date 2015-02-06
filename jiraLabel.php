<?php
//to execute in bash
//php jiraLabel.php YOUR_SUBDOMAIN.atlassian.net YOUR_BASE64_ENCODED_(user:pass) "status%20in%20(Validated)%20AND%20project%20in%20(EMKI)" YOUR_LABEL
call_user_func(function($argv){
	$jira = call_user_func_array(function($filename, $jira_uri, $jira_auth, $query_string, $label) {
		return (object) array(
			'uri' => $jira_uri,
			'auth' => $jira_auth,
			'jql' => $query_string,
			'label' => $label,
			'putLabelString' => "curl -s -X PUT --data '{ \"fields\": { \"labels\":@labels } }' -H \"Authorization: Basic $jira_auth\" -H \"Content-Type: application/json\" https://$jira_uri/rest/api/2/issue/@key",//"String to update label
			'getIssuesString' => "curl -s -X GET -H \"Authorization: Basic $jira_auth\" \
				-H \"Content-Type: application/json\" \"https://$jira_uri/rest/api/2/search?jql=$query_string\"",//"String to get stories
		);
	}, $argv);

	$issues = call_user_func(function($jira){
		$response = call_user_func(function() use ($jira) {
			try {
				if(($jres = json_decode(`{$jira->getIssuesString}`, true))) {
					return $jres;
				}
				throw new ErrorException("UNAUTHORIZED");
			} catch(Exception $e) {
				error_log('ERROR: Could not retrieve issues!!!');
				error_log($e->getMessage());
				return array();
			}
		});
		return (isset($response['issues'])? $response['issues']: array());
	}, $jira);

	array_map(function($issue) use ($jira){
		try {
			$labels = str_replace("\\\\", "\\", json_encode(array_unique(array_merge(array_map(function($label) { return str_replace("'", "\u0027", $label); }, $issue['fields']['labels']), array($jira->label)))));
			error_log("{$issue['key']}: $labels");
			$cmd = str_replace('@key', $issue['key'], str_replace("@labels", $labels, $jira->putLabelString));
			`$cmd`;
		}	catch(Exception $e) {
			error_log("Could not set label");
			error_log($e->getMessage());
		}
	}, $issues);
}, $argv);
