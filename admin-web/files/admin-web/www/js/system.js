var clearInitData;

$(function() {
	var str = "<option data='GMT0' value='UTC'>UTC</option>";
	if (typeof TZdata == "object") {
		for (var k in TZdata) {
			str += "<option data='" + TZdata[k] + "' value='" + k + "'>" + k + "</option>";
		}
	}
	$("#zonename").html(str);

	createInitModal();
	// verifyEventsInit();
	initEvents();
	initData();
	
});

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		updateTimes();
   	}, 5000);
}

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	ucicall("GetSystem", function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			jsonTraversal(d.data, jsTravSet);
			setTimeInitData();
		}
	})
}

function updateTimes(times) {
	ucicall("GetSystem", function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			$("#times").val(d.data.times);
			setTimeInitData();
		}
	});
}

function initEvents() {
	$(".refresh").on("click", OnRefresh);
	$(".submit").on("click", OnSubmit);
}

function OnRefresh() {
	var obj = {};
	var myDate = new Date();
	var times = myDate.toLocaleDateString().replace(/\//g, "-") + " " + myDate.getHours() + ":" + myDate.getMinutes() + ":" + myDate.getSeconds();
	
	obj.refresh = $.cookie("refresh");
	obj.times = times;
	
	$(".refresh i").addClass("icon-spin");
	ucicall("SyncTimes", obj, function(d) {
		if (d.status == 0 && typeof d.data != "undefined") {
			$(".refresh i").removeClass("icon-spin");
			$("#times").val(d.data);
			setTimeInitData();
		}
	})
}

function OnSubmit() {
	var debug_switch = $("#debug_switch").val(),
		g_ledctrl = $("#g_ledctrl").val(),
		zonename = $("#zonename option:selected").val(),
		timezone = $("#zonename option:selected").attr("data"),
		obj = {
			"debug_switch": debug_switch,
			"g_ledctrl": g_ledctrl,
			"zonename": zonename,
			"timezone": timezone
		};
	
	ucicall("SetSystem", obj, function(d) {
		if (d.status == 0) {
			cgicall("DebugSwitch", debug_switch, function(d) {})
			cgicall("LedctrlSwitch", g_ledctrl, function(d) {})
			initData();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！");
		}
	});
}
