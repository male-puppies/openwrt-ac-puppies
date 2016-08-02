var oTabRoutes,
	clearInitData;

$(function() {
	oTabRoutes = createDtRoutes();
});

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
   	}, 5000);
}

function createDtRoutes() {
	var cmd = {"key": "GetRoutes"}
	return $("#table_routes").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"ajax": {
			"url": "/call/ucicall",
			"type": "POST",
			"data": {
				"cmd": JSON.stringify(cmd)
			},
			"dataSrc": function(json) {
				if (json.status == 0) {
					return dtObjToArray(json.data);
				} else if (json.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				} else {
					console.log("dataTables POST error...");
					return [];
				}
			}
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
			{
				"data": "dev"
			},
			{
				"data": "dest"
			},
			{
				"data": "gateway"
			},
			{
				"data": "metric"
			},
			{
				"data": "table"
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		},
		"initComplete": function() {
			setTimeInitData();
		}
	});
}
function initData() {
	dtReloadData(oTabRoutes, false, function(d) {
		setTimeInitData();
	});
}
