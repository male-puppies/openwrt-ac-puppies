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
	var args = '["time","zonename"]';
	var obj = {keys: encodeURI(args)};
	cgicall.get("system_get", obj, function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			jsonTraversal(d.data, jsTravSet);
			setTimeInitData();
		}
	})
}

function updateTimes() {
	var args = '["time"]';
	var obj = {keys: encodeURI(args)};
	cgicall.get("system_get", obj, function(d) {
		if (d.status == 0 && typeof d.data == "object") {
			$("#time").val(d.data.time);
			setTimeInitData();
		}
	});
}

function initEvents() {
	$(".refresh").on("click", OnRefresh);
	$(".submit").on("click", OnSubmit);
}

function OnRefresh() {
	var obj = {
		cmd: "synctime",
		sec: Date.parse(new Date()) / 1000
	}

	$(".refresh i").addClass("icon-spin");
	cgicall.post("system_set", obj, function(d) {
		if (d.status == 0) {
			$(".refresh i").removeClass("icon-spin");
			updateTimes();
		}
	})
}

function OnSubmit() {
	var obj = {
		cmd: "timezone",
		zonename: $("#zonename option:selected").val()
	}

	cgicall.post("system_set", obj, function(d) {
		if (d.status == 0) {
			initData();
			createModalTips("保存成功！");
		} else {
			createModalTips("保存失败！" (d.data ? d.data : ""));
		}
	});
}
