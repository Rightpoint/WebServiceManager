<?php
	$data = [
		"postData" => $_POST,
		"postBinaryData" => $_FILES,
	];

    echo json_encode($data);
?>