var oTabUsers,
	clearInitData;

$(function() {
	oTabUsers = createDtUsers();
});

function createDtUsers() {
	var cmd = {"key": "ApmListUsers"}
	return $("#table_onlineuser").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"ajax": {
			"url": "/call/cgicall",
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
				"data": "mac"
			},
			{
				"data": "band",
				"render": function(d, t, f) {
					return d.toUpperCase();
				}
			},
			{ 
				"data": "ip",
				"render": function(d, t, f){
					return d == "" ? "waiting..." : d;
				}
			},
			{
				"data": "ap_describe",
				"render": function(d, t, f) {
					var data = d;
					if (data == "default" || data == "") data = f.ap;
					return '<span style="display:none;">' + f.ap + '</span><a class="underline" href="apstatus.html?filter='+ f.ap +'">' + data + '</a>';
				}
			},
			{
				"data": "ssid",
				"width": 180,
				"render": function(d, t, f) {
					var rssi = parseInt(f['rssi']);
					var str = '(' + rssi + 'dBm) ' + d;
					return '<div class="prorssi" value="' + RssiConvert(rssi) + '"><div class="prorssi-bar" style="width:'+RssiConvert(rssi)+'%;"></div><div class="prorssi-tip">' + str + '</div></div>';
				}
			},
			{
				"data": "status",
				"render": function(d, t, f){
					var str = '<span style="color: ';
					if (d == "1") {
						str += 'green;">在线';
					}else {
						str += 'red;">离线';
					}
					return str + '</span>';
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			$('.prorssi').each(function(index, element) {
				var val = $(element).attr("value");
				$(element).find('.prorssi-bar').css('background-color', RssiColor(val));
			});
		},
		"initComplete": function() {
			//过滤
			var furl = getRequestFilter();
			if (furl != "") {
				this.fnFilter(furl);
			}
			
			setTimeInitData();
		}
	});
}

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
   	}, 10000);
}

function initData() {
	dtReloadData(oTabUsers, false, function(d) {
		setTimeInitData();
	});
}

function getRequestFilter() {
	var arr,
		restr = "",
		obj = {},
		url = window.location.search;
		
	if (url && url != "") {
		url = url.substring(1);
		arr = url.split("&");
		
		for (var i = 0; i < arr.length; i ++) {
			obj[arr[i].split("=")[0]] = arr[i].split("=")[1];
		}
		
		if ("filter" in obj) {
			restr = obj.filter.split("||").join(" ");
		}
	}
	return decodeURI(restr);
}

function RssiConvert(d) {
	var num = parseInt(d);
	var per = Math.round((100*num + 11000)/75); //-30信号强度为100%,-110为0%
	if (per < 0) per = 0;
	if (per > 100) per = 100;
	return per;
}

function RssiColor(sRate) {
	var r = 0,
		g = 0,
		b = 0,
		rate = parseInt(sRate);

	r = (0 - 220)/100 * rate + 220;
	g = (170 - 220)/100 * rate + 220;
	b = 220;

	return 'rgb(' + parseInt(r) + ', ' + parseInt(g) + ', ' + parseInt(b) + ')';
}

