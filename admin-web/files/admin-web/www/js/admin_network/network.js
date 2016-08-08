var g_networks;

$(function() {
	initData();
	verifyEventsInit();
	initEvents();
})

function initData() {
	cgicall.get("iface_get", function(d) {
		if (d.status == 0 && typeof d.data != "undefined") {
			(new initHtml(d.data)).init();
		} else {
			createModalTips("初始化失败！请尝试重新加载！");
		}
	});
}

function initHtml(datas) {
	var nameReplace = function(str) {
		var obj = {},
			upper = ["单", "双", "三", "四", "五", "六", "七", "八", "九", "十"],
			reg = new RegExp("([0-9])lan([0-9])wan", "g");

		if (reg.test(str)) {
			obj.lan = parseInt(RegExp.$1) - 1;
			obj.wan = parseInt(RegExp.$2) - 1;
		} else if (str == "custom") {
			return "自定义模式";
		} else {
			return str.toUpperCase();
		}
		
		return upper[obj.lan] + "LAN " + upper[obj.wan] + "WAN模式";
	}

	var configWanLan = function() {
		var arr = getSelectEth();
		var obj = {
			"wan": [],
			"lan": []
		};
		for (var i = 0, ien = arr.length; i < ien; i++) {
			var eth = arr[i];
			if (eth != "wan0" && eth != "lan0") {
				if (eth.indexOf("wan") > -1 && $.inArray(eth, obj.wan) == -1) {
					obj.wan.push(eth);
				} else if (eth.indexOf("lan") > -1 && $.inArray(eth, obj.lan) == -1) {
					obj.lan.push(eth);
				}
			}
		}
		obj.wan.sort();
		obj.lan.sort();
		return obj;
	}

	this.datas = (function(d) {
		var datas = ObjClone(d);
		var network = datas.network.network;
		var networks = datas.networks;
		for (var k in network) {
			var ipd = network[k].ipaddr;
			if (typeof ipd != "undefined") {
				var ipd_arr = ipd.split("/");
				network[k].ipaddr = ipd_arr[0];
				if (ipd_arr.length > 1) {
					network[k].netmask = cidrToMaskstr(ipd_arr[1]);
				} else {
					network[k].netmask = "";
				}
			}

			var fdns;
			if (k.indexOf("wan") > -1) {
				fdns = network[k];
			} else {
				fdns = network[k]["dhcpd"];
			}
			var dns = network[k].dns;
			if (typeof fdns["dns"] != "undefined") {
				var dns_arr = fdns["dns"].split(",");
				fdns["dns1"] = dns_arr[0] || "";
				fdns["dns2"] = dns_arr[1] || "";
				delete fdns["dns"];
			}

			var ltime = network[k].dhcpd.leasetime
			if (typeof ltime != "undefined") {
				network[k].dhcpd.leasetime = parseInt(ltime);
			}
		}
		datas.networks = networks;

		for (var k in networks) {
			var ipd = networks[k].ipaddr;
			if (typeof ipd != "undefined") {
				var arr = ipd.split("/");
				networks[k].ipaddr = arr[0];
				if (arr.length > 1) {
					networks[k].netmask = cidrToMaskstr(arr[1]);
				} else {
					networks[k].netmask = "";
				}
			}

			var fdns;
			if (k.indexOf("wan") > -1) {
				fdns = networks[k];
			} else {
				fdns = networks[k]["dhcpd"];
			}
			var dns = networks[k].dns;
			if (typeof fdns["dns"] != "undefined") {
				var dns_arr = fdns["dns"].split(",");
				fdns["dns1"] = dns_arr[0] || "";
				fdns["dns2"] = dns_arr[1] || "";
				delete fdns["dns"];
			}

			var ltime = networks[k].dhcpd.leasetime
			if (typeof ltime != "undefined") {
				networks[k].dhcpd.leasetime = parseInt(ltime);
			}
		}
		datas.network.network = network;

		g_networks = ObjClone(datas.networks);
		return datas;
	}(datas));

	this.setOptsHtml = function() {
		var self = this,
			opts = this.datas.options,
			setnode = $("#select_opts"),
			select = $("<select/>", {
				"class": "form-control select-opts"
			});

		for (var i = 0, ien = opts.length; i < ien; i++) {
			var name = opts[i]["name"];
			select[0][i] = new Option(nameReplace(name), name);
		}
		
		setnode.html(select);
		$(".select-opts", setnode).on("change", function() {
			var val = $(this).val();
			var arr;
			if (val == "custom" && self.datas.network.name == "custom") {
				arr = self.numberNetwork(val);
			} else {
				arr = self.numberOpts(val);
			}
			self.consOptsHtml(arr, val);
			self.setConfigHtml();
		});
	}

	this.numberOpts = function(val) {
		var map = {};
		var arr = [];
		var opts = this.datas.options;
		for (var i = 0, ien = opts.length; i < ien; i++) {
			if (opts[i]["name"] == val) {
				map = opts[i]["map"];
				break;
			}
		}

		for (var k in map) {
			for (var i = 0, ien = map[k].length; i < ien; i++) {
				arr.splice(map[k][i] - 1, 0, k);
			}
		}
		
		return arr;
	}
	
	this.consOptsHtml = function(arr, val) {
		var self = this;
		var ien = arr.length;
		var setnode = $("#eth_ops").empty();

		for (var i = 0; i < ien; i++) {
			var node_s = $("<div>", {
					"class": "opt-select"
				});

			if (val == "custom" && i !== 0 && i !== ien - 1) {
				var select = $("<select>", {
					"class": "form-control input-sm"
				});
				for (var s = 0; s < ien - 1; s++) {
					select[0][s] = new Option("lan" + s, "lan" + s);
				}

				for (var w = s, len = 0; w < (ien - 1) * 2; w++) {
					var wanN = "wan" + (w - s);
					var inleng = $.inArray(wanN, arr);
					if (inleng > -1 && i != inleng) {
						len++;
					} else {
						select[0][w - len] = new Option(wanN, wanN);
					}
				}
				
				node_s = node_s.append(select);
				select.val(arr[i]);
				
				$("select", node_s).on("change", function() {
					self.consOptsHtml(getSelectEth(), val);
					self.setConfigHtml();
				})
			} else {
				node_s = node_s.html(arr[i]);
			}

			var node = $("<div>", {
						"class": "options"
					})
					.append($("<div>", {
							"class": "opt-icon " + arr[i]
						})
					)
					.append(node_s)
					.appendTo(setnode);
		}
	}
	
	this.setConfigHtml = function() {
		var obj = configWanLan(),
			lan_arr = obj.lan,
			wan_arr = obj.wan,
			str_lan = '<li class="active"><a href="#tabs_lan0" data-toggle="tab">lan0</a></li>',
			str_wan = '<li class="active"><a href="#tabs_wan0" data-toggle="tab">wan0</a></li>';

		$("#form_wan .tab-pane").each(function(index, element) {
			var has_id = $(element).attr("id").replace("tabs_", "");
			if ($.inArray(has_id, wan_arr) == -1 && has_id != "wan0") {
				$(element).remove();
			}
		});

		$("#form_lan .tab-pane").each(function(index, element) {
			var has_id = $(element).attr("id").replace("tabs_", "");
			if ($.inArray(has_id, lan_arr) == -1 && has_id != "lan0") {
				$(element).remove();
			}
		});

		for (var w = 0, wen = wan_arr.length; w < wen; w++) {
			str_wan += '<li><a href="#tabs_' + wan_arr[w] + '" data-toggle="tab">' + wan_arr[w] + '</a></li>';
			this.consConfigHtml("wan", wan_arr[w]);
		}

		for (var l = 0, len = lan_arr.length; l < len; l++) {
			str_lan += '<li><a href="#tabs_' + lan_arr[l] + '" data-toggle="tab">' + lan_arr[l] + '</a></li>';
			this.consConfigHtml("lan", lan_arr[l]);
		}

		$("#form_wan .nav").html(str_wan);
		$("#form_lan .nav").html(str_lan);
		$("#tabs_wan0").addClass("active").siblings().removeClass("active");
		$("#tabs_lan0").addClass("active").siblings().removeClass("active");
	}
	
	this.consConfigHtml = function(str, eth) {
		var id = "#tabs_" + eth,
			temp,
			result,
			results;

		if ($(id).length > 0) {
			return;
		}
		if (str == "wan") {
			temp = $("#tabs_wan0").html();
			result = temp.replace(/wan0__/g, eth + "__");
			results = '<div class="tab-pane" data-mtip="' + eth + '" id="tabs_' + eth + '">' + result + '</div>';
			$("#form_wan .tab-content").append(results);
			this.setValue(eth);
		} else {
			temp = $("#tabs_lan0").html();
			result = temp.replace(/lan0__/g, eth + "__");
			results = '<div class="tab-pane" data-mtip="' + eth + '" id="tabs_' + eth + '">' + result + '</div>';
			$("#form_lan .tab-content").append(results);
			this.setValue(eth);
		}
		$(id + ' [data-toggle="tooltip"]').tooltip();
		verifyEventsInit(id);
		$(id).find(".has-error").removeClass("has-error");
	}

	this.setValue = function(eth) {
		var arr = [],
			val = this.datas.network.name,
			network = this.datas.network.network,
			networks = this.datas.networks;

		if (eth) {
			arr.push(eth);
		} else {
			//无eth时，为初始化赋值
			var init_arr = this.numberNetwork(val);
			$("#select_opts select").val(val);
			this.consOptsHtml(init_arr, val);
			this.setConfigHtml();
			for (var k in network) {
				arr.push(k);
			}
		}

		for (var i = 0, ien = arr.length; i < ien; i++) {
			var data, obj = {};
			if (typeof network[arr[i]] != "undefined") {
				data = network[arr[i]];
			} else if (typeof networks[arr[i]] != "undefined") {
				data = networks[arr[i]];
			} else {
				return;
			}

			obj[arr[i]] = data;
			jsonTraversal(obj, jsTravSet);
			
			if (arr[i].indexOf("wan") > -1) {
				var s_arr = getSelectEth();
				var num = $.inArray(arr[i], s_arr);
				if (num > -1) {
					$("#" + arr[i] + "__mac").attr("placeholder", this.datas.ports[num]["mac"] || "");
				}
			}
		}

		OnCheckProto();
		OnCheckDhcp();
	}
	
	this.numberNetwork = function(val) {
		var arr = [];
		var network = this.datas.network.network;
		
		for (var k in network) {
			var ports = network[k]["ports"] || [];
			for (var i = 0, ien = ports.length; i < ien; i++) {
				arr.splice(ports[i] - 1, 0, k);
			}
		}

		return arr;
	}
	
	this.init = function() {
		this.setOptsHtml()
		this.setConfigHtml();
		this.setValue();
	}
}

//65535 -> "0.0.255.255"
function intToIpstr(ip) {
	return String((ip >>> 24) & 0xff) + "." + String((ip >>> 16) & 0xff) + "." + String((ip >>> 8) & 0xff) + "." + String((ip >>> 0) & 0xff);
}

//0.0.255.255 -> 65535 
function ipstrToInt(ipstr) {
	var ip = ipstr.split(".");
	return (Number(ip[0]) * 16777216) + (Number(ip[1]) * 65536) + (Number(ip[2]) * 256) + (Number(ip[3]) * 1);
}

//16 -> 0xffff0000 == 4294901760
//cidr = 1~32 cidr != 0
function cidrToInt(cidr) {
	var x = 0;
	for (var i = 0; i < cidr; i++) {
		x += (0x80000000 >>> i);
	}
	return x;
}

//4294901760 == 0xffff0000 -> 16
function intToCidr(ip) {
	for (var i = 0; i <= 31; i++) {
		if ((ip & (1<<(31-i))) == 0) {
			break;
		}
	}
	return i;
}

//16 -> "255.255.0.0"
function cidrToMaskstr(cidr) {
	var ip = cidrToInt(cidr);
	return intToIpstr(ip);
}

//"255.255.0.0" -> 16
function maskstrToCidr(maskstr) {
	var ip = ipstrToInt(maskstr);
	return intToCidr(ip);
}

//检查IP/MASK 对应的IP1 是否合法
//比如 IP=192.168.0.1 MASK=255.255.0.0 
// 那么 IP1=192.168.16.11 合法
// IP1=192.177.0.11 非法
// function checkIpMask(ipstr, maskstr, ipstr1) {
	// ip = ipstrToInt(ipstr);
	// mask = ipstrToInt(maskstr);
	// ip1 = ipstrToInt(ipstr1);
	// return (ip & mask) == (ip1 & mask);
// }

function getSelectEth() {
	var arr = [];
	$(".opt-select").each(function(index, element) {
		var self = $(element);
		if (self.find("select").length > 0) {
			arr.push(self.find("select").val());
		} else {
			arr.push(self.html());
		}
	});
	return arr;
}

function getSubmitObj() {
	var arr = getSelectEth(),
		nts_obj = {},
		ports = {},
		obj = {};

	for (var i = 0, ien = arr.length; i < ien; i++) {
		ports[arr[i]] = ports[arr[i]] || [];
		ports[arr[i]].push(i + 1);
		if (typeof nts_obj[arr[i]] == "undefined" && typeof g_networks[arr[i]] != "undefined") {
			nts_obj[arr[i]] = g_networks[arr[i]];
		}
	}

	obj = jsonTraversal(nts_obj, jsTravGet);

	for (var k in obj) {
		var netmask = obj[k]["netmask"];
		if (typeof netmask != "undefined" && netmask != "") {
			obj[k]["ipaddr"] = obj[k]["ipaddr"] + "/" + maskstrToCidr(netmask);
		}
		delete obj[k]["netmask"];

		if (typeof obj[k]["dhcpd"] != "undefined" && typeof obj[k]["dhcpd"]["leasetime"] != "undefined" && obj[k]["dhcpd"]["leasetime"] != "") {
			obj[k]["dhcpd"]["leasetime"] = obj[k]["dhcpd"]["leasetime"] + "h";
		}
	
		var fdns;
		if (k.indexOf("wan") > -1) {
			fdns = obj[k];
		} else {
			fdns = obj[k]["dhcpd"];
		}

		fdns["dns"] = fdns["dns1"] || "";
		if (typeof fdns["dns2"] != "undefined" && $.trim(fdns["dns2"]) != "") {
			fdns["dns"] = fdns["dns"] + "," + fdns["dns2"];
		}
		delete fdns["dns1"];
		delete fdns["dns2"];
		
		obj[k]["ports"] = ports[k] || [];
	}
	
	obj = {
		"name": $("#select_opts select").val(),
		"network": obj
	}
	
	return obj;
}

function initEvents() {
	$(".submit").on("click", OnSubmit);
	$(".tab-content").on("click", ".check-dhcp input", OnCheckDhcp);
	$(".tab-content").on("click", ".check-connect input", OnCheckProto);
	$(".tab-content").on("click", ".showlock", OnShowlock);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSubmit() {
	if (!verification()) return false;

	var obj = getSubmitObj();
	var sobj = {
		"arg": JSON.stringify(obj)
	}
	cgicall.post("iface_set", sobj, function(d) {
		if (d.status == 0) {
			createModalTips("保存成功！");
			initData();
		} else {
			createModalTips("保存失败！");
		}
	});
}

function OnCheckDhcp() {
	$(".check-dhcp").each(function(index, element) {
		var checked = $(element).find("input").is(":checked");
		var node = $(element).nextAll(".form-group").find("input");
		if (checked) {
			node.prop("disabled", false);
		} else {
			node.prop("disabled", true);
		}
	});
}

function OnCheckProto() {
	$(".check-connect").each(function(index, element) {
		var checked = $(element).find("input[type='radio']:checked").val();
		$(element).nextAll(".form-group.ischeck").hide().find("input").prop("disabled", true);
		$(element).nextAll(".form-group.ischeck." + checked).show().find("input").prop("disabled", false);
	});
}

function OnShowlock(that) {
	var tt = $(this).closest(".form-group").find("input.form-control")
	if (tt.length > 0 && (tt.attr("type") == "text" || tt.attr("type") == "password")) {
		if (tt.attr("type") == "password") {
			$(this).find("i").removeClass("icon-lock").addClass("icon-unlock");
			tt.attr("type", "text");
		} else {
			$(this).find("i").removeClass("icon-unlock").addClass("icon-lock");
			tt.attr("type", "password")
		}
	}
}
