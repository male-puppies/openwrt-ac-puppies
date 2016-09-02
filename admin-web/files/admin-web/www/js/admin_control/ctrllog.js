$(function() {
	createDt();
});

function createDt() {
	var cgiobj = {
		"page": 1,
		"count": 10000
	}
	return $('#table_acrule').dataTable({
		"pagingType": "full_numbers",
		"ordering": false,
		"language": {"url": '../../js/lib/dataTables.chinese.json'},
		"ajax": {
			"url": cgiDtUrl("ctrllog_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60,
			},
			{
				"data": "user",
				"render": function(d, t, f) {
					if (typeof d.ip == "undefined" && d.ip.length == 0) {
						return "--";
					} else {
						return d.ip;
					}
				}
			},
			{
				"data": "user",
				"render": function(d, t, f) {
					if (typeof d.mac == "undefined" && d.mac.length == 0) {
						return "--";
					} else {
						return d.mac;
					}
				}
			},
			{
				"data": "rulename",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "tm",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "actions",
				"render": function(d, t, f) {
					if (d == "ACCEPT") {
						return "允许";
					} else if (d == "REJECT") {
						return "阻断";
					} else {
						return "其它";
					}
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		}
	});
}
