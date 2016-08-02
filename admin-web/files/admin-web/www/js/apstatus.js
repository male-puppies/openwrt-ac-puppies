var oTabAPs,
	oTabNaps,
	oTabUpgrade,
	nodeEdit = [],
	dtCountry,
	clearInitData,
	hideColumns = ["7", "9"],
	edit_radio_2g = {
		'ampdu': '1',
		'amsdu': '1',
		'bandwidth': 'auto',
		'beacon': '100',
		'channel_id': 'auto',
		'dtim': '1',
		'leadcode': '1',
		'power': 'auto',
		'remax': '4',
		'rts': '2347',
		'shortgi': '1',
		'switch': '1',
		'users_limit': '30',
		'wireless_protocol': 'bgn'
	},
	edit_radio_5g = {
		'ampdu': '1',
		'amsdu': '1',
		'bandwidth': 'auto',
		'beacon': '100',
		'channel_id': 'auto',
		'dtim': '1',
		'leadcode': '1',
		'power': 'auto',
		'remax': '4',
		'rts': '2347',
		'shortgi': '1',
		'switch': '1',
		'users_limit': '30',
		'wireless_protocol': 'an'
	};

$(function() {
	oTabAPs = createDtAps();
	oTabNaps = createDtNaps();
	oTabUpgrade = createDtUpgrade();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
   	}, 10000);
}

function createDtAps() {
	var firstHideCol = true;
	var cmd = {"key": "ApmListAPs"}
	return $("#table_apstaus").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"ajax": {
			"url": "/call/cgicall",
			"type": "POST",
			"data": {
				"cmd": JSON.stringify(cmd)
			},
			"dataSrc": function(json) {
				if (json.status == 0) {
					dtCountry = json.data.country;
					return dtObjToArray(json.data.APs);
				} else if (json.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				} else {
					dtCountry = "China";
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
				"data": "ap_describe"
			},
            {
				"data": "ip_address"
			},
			{
				"data": "current_users",
				"render": function(d, t, f) {
					return '<a class="underline" href="onlineuser.html?filter='+ f.mac +'">' + d + '</a>';
				}
			},
            {
				"data": "radio",
				"render": function(d, t, f) {
					return '<a class="underline" href="radiostatus.html?filter='+ f.mac +'">' + d.toUpperCase() + '</a>';
				}
			},
			{
				"data": "naps",
				"render": function(d, t, f) {
					return '<a href="javascript:;" onclick="openModalNaps(this)" data-toggle="tooltip" data-container="body" title="查看"><span class="badge">' + dtObjToArray(d).length + '</span></a>';
				}
			},
            {
				"data": "boot_time"
			},
			{
				"data": "online_time"
			},
            {
				"data": "firmware_ver",
				"render": function(d, t, f) {
					var str = d;
					var aVer = d.split('.');
					if (aVer && aVer.length > 4) {
						str = aVer[0] + '.' + aVer[4];
					};
					return str;
				}
			},
			{
				"data": "state",
				"render": function(d, t, f) { //状态,online,offline
					var str = '<span style="color:';
					if (d.status == '1') {
						str += 'green;">在线';
					} else if (d.status == '2'){
						str += 'blue;">升级中';
					} else {
						str += 'grey;">离线';
					}
					str += "</span>"
					return str;
				}
			},
			{
				"data": null,
				"width": 80,
				"orderable": false,
				"render": function(d, t, f) {
					if (f.state.status == "0") {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
					} else {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger disabled" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
					}
				}
			},
			{
				"data": null,
				"width": 20,
				"orderable": false,
				"searchable": false,
				"defaultContent": '<input type="checkbox" value="1 0" />'
			}
        ],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			$("body > div.tooltip").remove();
			$('[data-toggle="tooltip"]').tooltip();
		},
		"preDrawCallback": function() {
			//放这里 解决闪现问题 加载只执行一次 回调过慢也会闪现
			if (firstHideCol) {
				initHideCol();
				firstHideCol = false;
			}
		},
		"initComplete": function() {
			//过滤
			var furl = getRequestFilter();
			if (furl != "") {
				this.fnFilter(furl);
			}
		}
	});
}

function createDtNaps() {
	return $("#table_naps").dataTable({
		"pagingType": "full_numbers",
		"order": [[3, 'desc']],
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"columns": [
			{
				"data": "apid",
				"render": function(d, t, f) {
					if (f.desc && f.desc != '') {
						return d + '</br><span>' + f.desc + '</span>';
					} else {
						return d;
					}
				}
			},
			{
				"data": "apid",
				"render": function(d, t, f) {
					var g2 = f['2g'];
					var g5 = f['5g'];
					if (g2 && !g5) {
						return '2G';
					}
					if (!g2 && g5) {
						return '5G';
					}
					if (g2 && g5) {
						return '2G/5G';
					}
				}
			},
			{
				"data": "apid",
				"render": function(d, t, f) {
					var g2 = f['2g'];
					var g5 = f['5g'];
					if (g2 && !g5) {
						var cid1 = f['2g'].channel_id;
						return cid1;
					}
					if (!g2 && g5) {
						var cid2 = f['5g'].channel_id;
						return cid2;
					}
					if (g2 && g5) {
						var cid3 = f['2g'].channel_id;
						var cid4 = f['5g'].channel_id;
						return cid3 + "/" + cid4;
					}
				}
			},
			{
				"data": "apid",
				"width": 180,
				"render": function(d, t, f) {
					var g2 = f['2g'],
						g5 = f['5g'],
						str2,
						str5;

					if (g2 && !g5) {
						str2 = '2G (' + g2['rssi'] + 'dBm)';

						return '<div class="prorssi" value="' + RssiConvert(g2['rssi']) + '"><div class="prorssi-bar" style="width:'+RssiConvert(g2['rssi'])+'%;"></div><div class="prorssi-tip">' + str2 + '</div></div>';
					}
					if (!g2 && g5) {
						str5 = '5G (' + g5['rssi'] + 'dBm)';
						
						return '<div class="prorssi" value="' + RssiConvert(g5['rssi']) + '"><div class="prorssi-bar" style="width:'+RssiConvert(g5['rssi'])+'%;"></div><div class="prorssi-tip">' + str5 + '</div></div>';
					}
					if (g2 && g5) {
						str2 = '2G (' + g2['rssi'] + 'dBm)';
						str5 = '5G (' + g5['rssi'] + 'dBm)';

						return '<div class="prorssi" value="' + RssiConvert(g2['rssi']) + '"><div class="prorssi-bar" style="width:'+RssiConvert(g2['rssi'])+'%;"></div><div class="prorssi-tip">' + str2 + '</div></div><div class="prorssi" value="' + RssiConvert(g5['rssi']) + '"><div class="prorssi-bar" style="width:'+RssiConvert(g5['rssi'])+'%;"></div><div class="prorssi-tip">' + str5 + '</div></div>';
					}
				}
			}
		],
		"drawCallback": function() {
			$('.prorssi').each(function(index, element) {
				var val = $(element).attr("value");
				$(element).find('.prorssi-bar').css('background-color', RssiColor(val));
			});
		}
	});
}

function createDtUpgrade() {
	return $("#table_upgrade").dataTable({
		"pagingType": "full_numbers",
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"columns": [
			{
				"data": "cur",
				"render": function(d, t, f) {
					if (d && d != "") {
						return d;
					} else {
						return "--";
					}
				}
			},
			{
				"data": "new",
				"render": function(d, t, f) {
					if (d && d != "") {
						if (f.cur != d) {
							return "<span style='color: #d9534f;'>" + d + "</span>";
						} else {
							return "--";
						}
					} else {
						return "--";
					}
				}
			}
		]
	});
}

function createInitModal() {
	$("#modal_edit, #modal_upgrade, #modal_columns, #modal_naps, #modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function openModalNaps(that) {
	getSelected(that);
	var data = nodeEdit[0].naps;
	dtRrawData(oTabNaps, dtObjToArray(data));
	$("#modal_naps").modal("show")
}

function initData() {
	var obj = {};
	// getSelected(); //不要用这个 会覆盖全局
	var nodeEdit = dtGetSelected(oTabAPs);
	for (var i = 0; i < nodeEdit.length; i++) {
		obj[nodeEdit[i].mac] = "1";
	}

	dtReloadData(oTabAPs, false, function(d) {
		var rows = oTabAPs.api().rows(),
			data = rows.data(),
			nodes = rows.nodes();

		for (var j = 0; j < nodes.length; j++) {
			var mac = data[j].mac;
			if (mac in obj) {
				$(nodes[j]).addClass("row_selected").find('td input[type="checkbox"]').prop('checked', true);
			}
		}
		
		initHideCol();
	});	
}

function initHideCol() {
	cgicall("GetHideColumns", "webui/hidepage/wireless/apstatus", function(d) {
		var harr = hideColumns;
		if (d.status == 0) {
			if (Object.prototype.toString.call(d.data) === '[object Array]') {
				hideColumns = d.data;
				harr = d.data;
			}
		}
		dtHideColumn(oTabAPs, harr);
		setTimeInitData();
	});
}

function edit(that) {
	getSelected(that);
	if (nodeEdit.length < 1) {
		createModalTips("请选择要编辑的AP！");
		return;
	} else if (nodeEdit.length > 1) {
		setConfigDefault();		//批量修改 radio配置改成默认值
	}
	
	setCountryChannel(nodeEdit[0]);
	jsonTraversal(nodeEdit[0], jsTravSet);
	OnLanDHCPChg(nodeEdit.length);
	OnWorkMode(nodeEdit[0].edit.work_mode);
	htmlSetVal(nodeEdit.length);

	$('#modal_edit').modal("show");
}

//保存配置
function DoSave() {
	if (!verification()) return;

	var macarr = [],
		obj = {},
		ap = checkConfigKey(),
		apedit = jsonTraversal(ap, jsTravGet);
	
	for (var i = 0; i < nodeEdit.length; i++) {
		macarr.push(nodeEdit[i].mac);
	};

	obj.edit = apedit.edit;
	obj.aps = macarr;
	
	//工作信道批量
	if (macarr.length > 1) {
		if ($("#channel_2g_enable").is(":checked")) {
			obj.edit.radio_2g.batch_enable = "1";
		} else {
			obj.edit.radio_2g.batch_enable = "0";
		}
		
		if ($("#channel_5g_enable").is(":checked")) {
			obj.edit.radio_5g.batch_enable = "1";
		} else {
			obj.edit.radio_5g.batch_enable = "0";
		}
	}

	cgicall('ApmUpdateAps', obj, function(d) {
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("保存失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_edit", func);
	});
}

function DoRestart() {
	//获取选择ap列表
	var arr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		arr.push(nodeEdit[i].mac);
	}

	var obj = {};
	obj.cmd = 'rebootAps';
	obj.data = arr;
	cgicall('ApmExecCommands', obj, function(d) {
		var func = {
			"sfunc": function() {
				initData();
				createModalTips("重启成功，稍后将重新上线...");
			},
			"ffunc": function() {
				createModalTips("重启失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function DoReset() {
	var arr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		arr.push(nodeEdit[i].mac);
	}

	var obj = {};
	obj.cmd = 'rebootErase';
	obj.data = arr;
	cgicall('ApmExecCommands', obj, function(d) {
		var func = {
			"sfunc": function() {
				initData();
				createModalTips("正在恢复出厂配置，稍后将重新上线...");
			},
			"ffunc": function() {
				createModalTips("恢复出厂配置失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function DoDelete() {
	var arr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		arr.push(nodeEdit[i].mac);
	}

	cgicall('ApmDeleteAps', arr, function(d) {
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function DoUpgrade() {
	var arr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		arr.push(nodeEdit[i].mac);
	}

	cgicall('ApmUpdateFireware', arr, function(d) {
		var func = {
			"sfunc": function() {
				initData();
				createModalTips("正在升级，稍后将重新上线...");
			},
			"ffunc": function() {
				createModalTips("升级失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_upgrade", func);
	});
}

function DoDown() {
	cgicall('ApmFWDownload', function(d) {
		var func = {
			"sfunc": function() {
				createModalTips("正在下载，稍后可进行升级...", "DoDownAfter");
				$("#modal_tips .btn-modal").val("打开升级列表");
			},
			"ffunc": function() {
				createModalTips("下载失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_upgrade", func);
	});
}

function DoDownAfter() {
	cgicall("ApmFirewareList", function(d) {
		var func = {
			"sfunc": function() {
				dtRrawData(oTabUpgrade, dtObjToArray(d.data));
				$("#modal_upgrade").modal("show");
			},
			"ffunc": function() {
				createModalTips("加载失败！");
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function DoRefresh() {
	cgicall("ApmFirewareList", function(d) {
		if (d.status == 0) {
			dtRrawData(oTabUpgrade, dtObjToArray(d.data));
		} else {
			alert("刷新失败！");
		}
	});
}

function DoHidecolumns() {
	var obj = {};
	var hidenum = [];
	$('#modal_columns .checkbox input').each(function(index, element) {
		if (!$(element).is(":checked")) {
			hidenum.push(index);
		}
	});
	obj.page = 'webui/hidepage/wireless/apstatus';
	obj.data = hidenum;
	cgicall('DtHideColumns', obj, function(d) {
		var func = {
			"sfunc": function() {
				hideColumns = hidenum;
				dtHideColumn(oTabAPs, hidenum);
			},
			"ffunc": function() {
				createModalTips("操作失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_columns", func);
	});
}

function initEvents() {
	//click event
	$(".checkall").on("click", OnSelectAll);
	$('.edit').on('click', function() {edit()}); //编辑
	$('.restart').on('click', OnRestart); //重启AP
	$('.upgrade').on('click', OnUpgrade); //升级AP
	// $('.download').on('click', OnDownload); //下载AP固件
	$('.reset').on('click', OnReset); //恢复出厂配置
	$('.delete').on('click', function() {OnDelete()}); //删除
	$('.hidecol').on('click', OnHidecol);
	$('#btn_exec_cmd').on('click', OnGetApLog);
	$('#channel_2g_enable').on('click', OnChannelEn2);
	$('#channel_5g_enable').on('click', OnChannelEn5);
	$('fieldset.form-ff legend').on('click', OnLegend);

	//select event
	$('#edit__ip_distribute').on('change', OnLanDHCPChg); //DHCP分配
	$('#edit__work_mode').on('change', function() {
		var mode = $(this).find('option:selected').val();
		OnWorkMode(mode);
	}); //工作模式
	$('#edit__radio_2g__wireless_protocol').on('change', function() {
		var op = $(this).find('option:selected').val();
		channel_2gSet(op);
	});
	$('#edit__radio_5g__wireless_protocol').on('change', function() {
		var op = $(this).find('option:selected').val();
		channel_5gSet(op);
	});
	$("#edit__radio_2g__bandwidth").on('change', function() {
		var op = $(this).find('option:selected').val();
		country_2gSet(op);
	});
	$("#edit__radio_5g__bandwidth").on('change', function() {
		var op = $(this).find('option:selected').val();
		country_5gSet(op);
	});
	
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSelectAll() {
	dtSelectAll(this, oTabAPs);
}

function OnRestart() {
	getSelected();
	if (nodeEdit.length < 1) {
		createModalTips("选择要重启的AP！");
		return;
	}
	createModalTips("系统将会重启已选AP，重启会导致已经连接AP的用户短暂掉线。</br>是否确认重启？", "DoRestart");
}

function OnUpgrade() {
	getSelected();
	if (nodeEdit.length < 1) {
		createModalTips("选择要升级的AP！");
		return;
	}
	cgicall("ApmFirewareList", function(d) {
		if (d.status == 0) {
			dtRrawData(oTabUpgrade, dtObjToArray(d.data));
			$("#modal_upgrade").modal("show");
		} else {
			createModalTips("加载升级列表失败！请尝试重新加载！");
		}
	});
}

/* 
function OnUpgrade() {
	getSelected();
	if (nodeEdit.length < 1) {
		createModalTips("选择要升级的AP！");
		return;
	}
	cgicall("ApmFirewareList", function(d) {
		if (d.status == 0) {
			var data = dtObjToArray(d.data),
				strHtml = '';
			
			if (data.length == 0) {
				createModalTips("无可用固件，请尝试下载AP固件！");
			} else {
				for (var i = 0; i < data.length; i++) {
					strHtml += "<li>" + data[i] + "</li>";
				}
				createModalTips(strHtml, "DoUpgrade");
				// $('#ul_VerAcFirw').html(strHtml);
			}
		} else {
			createModalTips("请求升级固件失败！请尝试重新加载！");
			console.log("ApmFirewareList error " + (d.data ? d.data : ""));
		}
	});
}
 */

/* 
function OnDownload() {
	getSelected();
	if (nodeEdit.length < 1) {
		createModalTips("选择要下载固件的AP！");
		return;
	}
	var apfire = {};
	for (var i = 0; i < nodeEdit.length; i++) {
		var str = nodeEdit[i].firmware_ver
		var s = str.substring(0, str.indexOf("."));
		apfire[s] = "1";
	}
	var arr = [];
	for (var k in apfire) {
		arr.push(k);
	}
	cgicall('ApmFirewareDownload', arr, function(d) {
		if (d.status == 0) {
			createModalTips("正在下载，稍后可进行固件升级！");
		} else {
			createModalTips("下载失败！请尝试重新加载！");
		}
	})
}
 */

function OnReset() {
	getSelected();
	if (nodeEdit.length < 1) {
		createModalTips("选择要恢复的AP！");
		return;
	}
	createModalTips("将AP恢复到出厂状态，需要环境有DHCP服务，并和AC同网段才能重新上线。</br>确定要复位这些AP？", "DoReset");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length < 1) {
		createModalTips("请选择要删除的离线AP！");
		return;
	}
	for (var k in nodeEdit) {
		if (nodeEdit[k].state.status != '0') {
			createModalTips("只能删除离线AP！");
			return;
		}
	}
	createModalTips("删除离线AP时，同时会删除该AP的配置。</br>确定要删除此AP？", "DoDelete");
}

function OnHidecol() {
	$("#modal_columns .checkbox input").each(function(index, element) {
		$(element).prop('checked', true);
		for (var i = 0; i < hideColumns.length; i++) {
			if (hideColumns[i] == index) {
				$(element).prop('checked', false);
				break;
			}
		}
	});
	$('#modal_columns').modal("show");
}

function OnChannelEn2() {
	if ($('#channel_2g_enable').is(":checked")) {
		$('#edit__radio_2g__channel_id').prop('disabled', false);
	} else {
		$('#edit__radio_2g__channel_id').prop('disabled', true);
	}
}

function OnChannelEn5() {
	if ($('#channel_5g_enable').is(":checked")) {
		$('#edit__radio_5g__channel_id').prop('disabled', false);
	} else {
		$('#edit__radio_5g__channel_id').prop('disabled', true);
	}
}

function OnLanDHCPChg(num) {
	var en = $('#edit__ip_distribute').val();
	if (en == 'static') {
		en = false;
	} else {
		en = true;
	}
	$('#edit__ip_address,#edit__netmask,#edit__gateway,#edit__dns').prop('disabled', en);
	
	//common editor
	if (num && num > 1) {
		$('#edit__nick_name,#edit__ip_address,#edit__netmask,#edit__gateway').prop('disabled', true);
	} else {
		$('#edit__nick_name').prop('disabled', false);
	}
}

function OnWorkMode(o) {
	if (o == 'hybrid') {
		$('.mode_hybrid,.mode_normal').show().find('input').prop('disabled', false);
		$('.mode_monitor').hide().find('input').prop('disabled', true);
	} else if (o == 'normal') {
		$('.mode_hybrid,.mode_monitor,.mode_normal').hide().find('input').prop('disabled', true);
	} else if (o == 'monitor') {
		$('.mode_hybrid').hide().find('input').prop('disabled', true);
		$('.mode_monitor,.mode_normal').show().find('input').prop('disabled', false);
	}
}

function OnGetApLog() {
	if (nodeEdit.length < 1) {
		verifyModalTip("获取日志失败！请尝试重新加载！");
		return;
	}
	cgicall('GetApLog', nodeEdit[0].mac, function(d) {
		if (d.status == 0) {
			$('#LogRuntime').val(d.data);
		} else {
			verifyModalTip("获取日志失败！请尝试重新加载！");
		}
	});
}

function OnLegend() {
	var t = $(this).siblings(".form-hh");
	if (t.is(":hidden")) {
		$(this).find("span i").removeClass("icon-double-angle-down").addClass("icon-double-angle-up");
		t.slideDown(500);
	} else {
		$(this).find("span i").removeClass("icon-double-angle-up").addClass("icon-double-angle-down");
		t.slideUp(500);
	}
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabAPs.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabAPs);
	}
}

function htmlSetVal(num) {
	var Ulimit2g = $('#edit__radio_2g__users_limit');
	if (Ulimit2g.length > 0) {
		if (Ulimit2g.val() == '' || Ulimit2g.val() == 0) {
			Ulimit2g.val('30');
		}
	}
	var Ulimit5g = $('#edit__radio_5g__users_limit');
	if (Ulimit5g.length > 0) {
		if (Ulimit5g.val() == '' || Ulimit5g.val() == 0) {
			Ulimit5g.val('30');
		}
	}

	if (num > 1) {
		$('.channel_2g_big,.channel_5g_big').css('display', 'block');
		$('#channel_2g_enable,#channel_5g_enable').prop('checked', false).prop('disabled', false);
		$('#edit__radio_2g__channel_id,#edit__radio_5g__channel_id').prop('disabled', true);
	} else {
		$('.channel_2g_big,.channel_5g_big').css('display', 'none');
		$('#channel_2g_enable,#channel_5g_enable').prop('checked', true).prop('disabled', true);
		$('#edit__radio_2g__channel_id,#edit__radio_5g__channel_id').prop('disabled', false);
	}
}

function setConfigDefault() {
	var conf = ObjClone(nodeEdit[0]);
	var radio_2g = ObjClone(edit_radio_2g);
	var radio_5g = ObjClone(edit_radio_5g);
	if (typeof(conf['edit']['radio_2g']) != "undefined") {
		conf['edit']['radio_2g'] = radio_2g;
	}
	
	if (typeof(conf['edit']['radio_5g']) != "undefined") {
		conf['edit']['radio_5g'] = radio_5g;
	}
}

function checkConfigKey() {
	var conf = ObjClone(nodeEdit[0]);
	var radio_2g = ObjClone(edit_radio_2g);
	var radio_5g = ObjClone(edit_radio_5g);
	for (var k in radio_2g) {
		if (typeof(conf['edit']['radio_2g']) == "undefined") break;
		if (typeof(conf['edit']['radio_2g'][k]) == "undefined" || conf[k] == '') {
			conf['edit']['radio_2g'][k] = radio_2g[k];
		}
	}
	
	for (var k in radio_5g) {
		if (typeof(conf['edit']['radio_5g']) == "undefined") break;
		if (typeof(conf['edit']['radio_5g'][k]) == "undefined" || conf[k] == '') {
			conf['edit']['radio_5g'][k] = radio_5g[k];
		}
	}
	
	return conf;
}

function setCountryChannel(obj) {
	channel_2gSet(obj); //2g 信道带宽option设置
	channel_5gSet(obj);
	country_2gSet(obj); //国家码对应信道
	country_5gSet(obj);
}

function channel_2gSet(obj) {
	var op2,
		protocol,
		bol = true,
		pauto = '<option value="auto">auto</option>',
		p20 = '<option value="20">20</option>',
		p40p = '<option value="40+">40+</option>',
		p40m = '<option value="40-">40-</option>',
		band2g = $("#edit__radio_2g__bandwidth");

	if (typeof(obj) == 'object') {
		protocol = obj.edit.radio_2g.wireless_protocol;
		bol = false;
	} else {
		protocol = obj;
	}

	switch (protocol)
	{
		case 'b':
			band2g.html(p20);
			break;
		case 'g':
			band2g.html(p20);
			break;
		case 'n':
			band2g.html(pauto + p20 + p40p + p40m);
			break;
		case 'bg':
			band2g.html(p20);
			break;
		case 'bng':
			band2g.html(pauto + p20 + p40p + p40m);
			break;
		default:
			band2g.html(pauto + p20 + p40p + p40m);
			break;
	}
	
	if (bol) {
		op2 = $("#edit__radio_2g__bandwidth").find('option:selected').val();
		country_2gSet(op2);
	}
}

function channel_5gSet(obj) {
	var op2,
		protocol,
		bol = true,
		pauto = '<option value="auto">auto</option>',
		p20 = '<option value="20">20</option>',
		p40p = '<option value="40+">40+</option>',
		p40m = '<option value="40-">40-</option>',
		band5g = $("#edit__radio_5g__bandwidth");

	if (typeof(obj) == 'object') {
		protocol = obj.edit.radio_5g.wireless_protocol;
		bol = false;
	} else {
		protocol = obj;
	}
	
	switch (protocol)
	{
		case 'a':
			band5g.html(p20);
			break;
		case 'n':
			band5g.html(pauto + p20 + p40p + p40m);
			break;
		case 'an':
			band5g.html(pauto + p20 + p40p + p40m);
			break;
		default:
			band5g.html(pauto + p20 + p40p + p40m);
			break;
	}
	
	if (bol) {
		op2 = $("#edit__radio_5g__bandwidth").find('option:selected').val();
		country_5gSet(op2);
	}
}

function country_2gSet(obj) {
	var str_2g,
		cband,
		ctc_2g = [];
		
	if (typeof(obj) == 'object') {
		cband = obj.edit.radio_2g.bandwidth;
	} else {
		cband = obj;
	}
	ctc_2g = countryToSetChannel(dtCountry, cband, '2g');
	for (var k in ctc_2g) {
		str_2g += '<option>' + ctc_2g[k] + '</option>';
	}
	$("#edit__radio_2g__channel_id").html(str_2g);
}

function country_5gSet(obj) {
	var str_5g,
		cband,
		ctc_5g = [];
	
	if (typeof(obj) == 'object') {
		cband = obj.edit.radio_5g.bandwidth;
	} else {
		cband = obj;
	}
	ctc_5g = countryToSetChannel(dtCountry, cband, '5g');
	for (var k in ctc_5g) {
		str_5g += '<option>' + ctc_5g[k] + '</option>';
	}
	$("#edit__radio_5g__channel_id").html(str_5g);
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
