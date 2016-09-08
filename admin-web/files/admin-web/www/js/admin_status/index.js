var mark1,
	mark2,
	cpu_stat = {},
	clearInitData;

$(function() {
	Highcharts.setOptions({
		global: {
			useUTC: true
		},
		lang : {
			resetZoom: '原始尺寸',
			resetZoomTitle : ''
		}
	});
	$(".title i.spin-load").css("display", "inline-block");
	initEvents();
	initData1();
	initData3();
});

function initData1() {
	cgicall.get("system_sysinfo", function(d) {
		if (d.status == 0) {
			setSystem(d.data);
			setTimeout(initData1, 5000);
		}
	});
}

function initData3() {
	cgicall.get("system_ifaceinfo", function(d) {
		console.log(d)
		if (d.status == 0) {
			setInterface(d.data);
			setTimeout(initData3, 5000);
		}
	});
}

function containerEth() {
	var data = ObjClone(f1);
	var arr = containerCons(data);

	$('#container_eth').highcharts({
		chart: {
			type: 'areaspline',
			zoomType:'x'
		},
		colors: ['#7cb5ec', '#f7a35c'],
		title: {
			text: '网口实时流量',
			x: -20
		},
		subtitle: {
			text: ' ',
			x: -20
		},
		credits: {
			enabled: 0,
		},
		xAxis: {
			type: 'linear',
			allowDecimals: false,
			tickmarkPlacement: 'on',
			title: {
				text: '（时间）',
				align: 'high'
			},
			labels: {
				formatter: function() {
					return xtimes(this.value);
				}
			},
			tickInterval: 6
		},
		yAxis: {
			allowDecimals: false,
			min: 0,
			title: {
				text: '︵<br>流<br>量<br>︶',
				align: 'high',
				rotation: 0,
				style: {
					'lineHeight': '14px'
				}
			},
			labels: {
				formatter: function() {//纵轴返回值
					var kb = toDecimal(this.value/1000);
					if (kb == 0) {
						return kb
					} else if (kb < 1000) {
						return kb + 'KB';
					} else if (kb >= 1000 && kb < 1000000) {
						return toDecimal(kb/1000) + 'MB';
					} else if (kb >= 1000000) {
						return toDecimal(kb/1000000) + 'GB';
					}
				}
			}
		},
		tooltip: {
			formatter: function() {
				return '<b>' + xtimes(this.x) + '</b>：<b>' + this.y + '</b>';
			}
		},
		legend: {
			layout: 'vertical',
			align: 'right',
			verticalAlign: 'middle',
			borderWidth: 0
		},
		plotOptions: {
			series: {
				lineWidth: 0.5,
				marker: {
					enabled: false,
					states: {
						hover: {
							radius: 3
						}
					}
				},
				states: {
					hover: {
						lineWidth: 0.5,
						halo: {
							size: 5
						}
                    }
				}
			}
		},
		series: arr
	});
}

function containerUser() {
	var data = ObjClone(f1);
	var arr = containerCons(data);

	$('#container_user').highcharts({
		chart: {
			type: 'areaspline',
			zoomType:'x'
		},
		colors: ['#7cb5ec', '#f7a35c'],
		title: {
			text: '前十用户实时流量',
			x: -20
		},
		subtitle: {
			text: ' ',
			x: -20
		},
		credits: {
			enabled: 0,
		},
		xAxis: {
			type: 'linear',
			allowDecimals: false,
			tickmarkPlacement: 'on',
			title: {
				text: '（时间）',
				align: 'high'
			},
			labels: {
				formatter: function() {
					return xtimes(this.value);
				}
			},
			tickInterval: 6
		},
		yAxis: {
			allowDecimals: false,
			min: 0,
			title: {
				text: '︵<br>流<br>量<br>︶',
				align: 'high',
				rotation: 0,
				style: {
					'lineHeight': '14px'
				}
			},
			labels: {
				formatter: function() {//纵轴返回值
					var kb = toDecimal(this.value/1000);
					if (kb == 0) {
						return kb
					} else if (kb < 1000) {
						return kb + 'KB';
					} else if (kb >= 1000 && kb < 1000000) {
						return toDecimal(kb/1000) + 'MB';
					} else if (kb >= 1000000) {
						return toDecimal(kb/1000000) + 'GB';
					}
				}
			}
		},
		tooltip: {
			formatter: function() {
				return '[<b>' + (parseInt(this.x) + 1) + '</b>] - [<b>' + this.y + '</b>]';
			}
		},
		legend: {
			layout: 'vertical',
			align: 'right',
			verticalAlign: 'middle',
			borderWidth: 0
		},
		plotOptions: {
			series: {
				lineWidth: 0.5,
				marker: {
					enabled: false,
					states: {
						hover: {
							radius: 3
						}
					}
				},
				states: {
					hover: {
						lineWidth: 0.5,
						halo: {
							size: 5
						}
                    }
				}
			}
		},
		series: arr
	});
}

function containerCons(d) {
	var data_arr = [],
		data = ObjClone(d);

	for (var i = 0, ien = data.recv.length; i < ien; i++) {
		if (typeof data.recv[i].name != "undefined") {
			data.recv[i].name = data.recv[i].name + " 下行";
		}
		if (typeof data.xmit[i].name != "undefined") {
			data.xmit[i].name = data.xmit[i].name + " 上行";
		}

		var recv_data = data["recv"][i]["data"];
		if (typeof recv_data != "undefined") {
			data["recv"][i]["data"] = cons(recv_data.length, recv_data);
			data_arr.push(data.recv[i]);
		}

		var xmit_data = data["xmit"][i]["data"];
		if (typeof xmit_data != "undefined") {
			data["xmit"][i]["data"] = cons(xmit_data.length, xmit_data);
			data_arr.push(data.xmit[i]);
		}
	}
	return data_arr;

	function cons(ien, data) {
		var i = 0,
			arr = [];

		if (ien < 60) {
			for (var s = 0; s < 60 - ien; s++) {
				arr.push(0);
			}
		} else if (ien > 60) {
			i = ien - 60
		}

		for (; i < ien; i++) {
			arr.push(data[i]);
		}

		return arr;
	}
}

function setSystem(d) {
	var cpu = 0,
		memory = parseInt(d.memory.used) * 100 / parseInt(d.memory.total),
		conncount = parseInt(d.connection.count) * 100 / parseInt(d.connection.max);

	if (typeof cpu_stat.idle != "undefined") {
		var iowait = parseInt(d.cpu_stat.iowait) - parseInt(cpu_stat.iowait),
			idle = parseInt(d.cpu_stat.idle) - parseInt(cpu_stat.idle),
			user = parseInt(d.cpu_stat.user) - parseInt(cpu_stat.user),
			irq = parseInt(d.cpu_stat.irq) - parseInt(cpu_stat.irq),
			softirq = parseInt(d.cpu_stat.softirq) - parseInt(cpu_stat.softirq),
			system = parseInt(d.cpu_stat.system) - parseInt(cpu_stat.system),
			nice = parseInt(d.cpu_stat.nice) - parseInt(cpu_stat.nice);

		cpu = parseInt((iowait + user + irq + softirq + system + nice) / (iowait + user + irq + softirq + system + nice + idle) * 100);
		$(".cpu-mark").hide();
	}
	cpu_stat = d.cpu_stat;

	$("#distribution").html(d.distribution);
	$("#version").html(d.version);
	$("#times").html(d.time);
	$("#uptime").html(arrive_timer_format(d.uptime));
	$("#usercount").html(d.onlineuser.count);

	$("#cpuidle").data('radialIndicator').animate(cpu);
	$(".cpuidle").html(cpu + " / " + "100");
	$("#memory").data('radialIndicator').animate(memory);
	$(".memory").html(parseInt(d.memory.used / 1000) + " KB / " + parseInt(d.memory.total / 1000) + " KB");
	$("#conncount").data('radialIndicator').animate(conncount);
	$(".conncount").html(d.connection.count + " / " + d.connection.max);

	$(".title i.spin-load1").css("display", "none");
}

function setInterface(d) {
	var layout = d.layout,
		stat = d.stat,
		len = layout.length,
		cclass = "col-md-2";

	if (typeof layout == "undefined" || typeof stat == "undefined") return;

	if (len == 5) {
		cclass = "col-md-5ths";
	} else if (len < 5) {
		cclass = "col-md-" + parseInt(12 / len);
	}

	$("ul.network").empty();
	for (var i = 0; i < len; i++) {
		var l_data = layout[i],
			name = l_data.name,
			s_data = stat[name] || {},
			bgoption = "0 -240px",
			node;

		if (typeof l_data["is_up"] != "undefined" && l_data["is_up"] == 1) {
			if (name.indexOf("wan") > -1) {
				bgoption = "0 0";
			} else if (name.indexOf("lan") > -1) {
				bgoption = "0 -120px";
			}
		}

		node = $("<li>", {
					"class": "item port" + i + " " + cclass
				})
				.append($("<div>", {
						"class": "zone-big",
						"style": "background-position:" + bgoption
					})
					.append($("<div>", {
							"class": "zone"
						})
						.append($("<span>").html(name !== "" ? name : "关闭"))
					)
					.append($("<div>", {
							"class": "speed-duplex"
						})
						.append($("<span>", {
								"class": "speed"
							})
							.html(
								(function() {
									var d = backdata(l_data, "speed");
									if (d === "--" || d === "") return "--";
									return d;
								}())
							)
						)
						.append($("<span>", {
								"class": "duplex"
							})
							.html(
								(function() {
									var d = backdata(l_data, "duplex");
									if (d === "--" || d === "") return " --";
									return d === "full" ? " 全双工" : " 半双工";
								}())
							)
						)
					)
				)
				.append($("<ul>", {
						"class": "net-eth"
					})
					.append($("<li>").html("类型: ")
						.append($("<span>").html(backdata(s_data, "proto")))
					)
					.append($("<li>").html("地址: ")
						.append($("<span>").html(
							(function(){
								var d = backdata(s_data, "ipaddrs");
								if (d == "--") return d;
								return backdata(s_data, "ipaddrs")[0] ? backdata(s_data, "ipaddrs")[0] : "--";
							}())
						))
					)
					.append($("<li>").html("网关: ")
						.append($("<span>").html(backdata(s_data, "gwaddr")))
					)
					.append($("<li>").html("DNS 1: ")
						.append($("<span>").html(
							(function() {
								var d = backdata(s_data, "dnsaddrs");
								if (d === "--") return d;
								return backdata(s_data, "dnsaddrs")[0] ? backdata(s_data, "dnsaddrs")[0] : "--";
							}())
						))
					)
					.append($("<li>").html("DNS 2: ")
						.append($("<span>").html(
							(function() {
								var d = backdata(s_data, "dnsaddrs");
								if (d === "--") return d;
								return backdata(s_data, "dnsaddrs")[1] ? backdata(s_data, "dnsaddrs")[1] : "--";
							}())
						))
					)
					.append($("<li>").html("运行: ")
						.append($("<span>").html(
								(function() {
									var d = backdata(s_data, "uptime");
									if (d === "--") return d;
									return arrive_timer_format(d);
								}())
							)
						)
					)
				)

		$("ul.network").append(node);
	}

	$(".title i.spin-load2").css("display", "none");

	function backdata(data, o) {
		if (typeof data[o] === "undefined") {
			return "--";
		} else {
			return data[o];
		}
	}
}

function initEvents() {
	$('#cpuidle').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#6dd0ef',
		barColor: '#fff'
	});
	$('#memory').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#fad774',
		barColor: '#fff'
	});
	$('#conncount').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#f4866d',
		barColor: '#fff'
	});
}

function arrive_timer_format(s) {
	var t = "",
		s = parseInt(s);

	if (s > -1) {
		var hour = Math.floor(s / 3600) % 24,
			min = Math.floor(s / 60) % 60,
			sec = s % 60,
			day = parseInt(s / (3600 * 24));

		if (sec != 0) {
			t = sec + "秒";
		}
		if (min > 0) {
			t = min + "分 " + t;
		}
		if (hour > 0) {
			t = hour + "时 " + t;
		}
		if (day > 0) {
			t = day + "天 " + t;
		}
	}
	return t;
}

function xtimes(num) {
	var s = (60 - parseInt(num)) * 5;
	return arrive_timer_format(s);
}

function toDecimal(x) {
	var f = parseFloat(x);
	if (isNaN(f)) {
		return;
	}
	f = Math.round(x*100)/100;
	return f;
}

function initBandwidthNum(bps, ser_name) {
	var kbps = toDecimal(bps/1000);
	if (kbps < 1) {
		return ser_name + '：' + bps + 'bps';
	} else if (kbps >= 1 && kbps < 1000) {
		return ser_name + '：' + kbps + 'Kbps';
	} else if (kbps >= 1000) {
		return ser_name + '：' + toDecimal(kbps/1000) + 'Mbps';
	}
}
