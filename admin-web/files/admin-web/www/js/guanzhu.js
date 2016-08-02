function is_weixin() {
	var ua = navigator.userAgent.toLowerCase();
	if (ua.match(/MicroMessenger/i) == "micromessenger") {
		return true;
	} else {
		return false;
	}
}

window.onload = function() {
	if (!is_weixin()) {
		alert("请在微信中打开！");
	}
}

function go_weixin(origin_id, jump_href) {
	WeixinJSBridge.invoke("addContact", {
		webtype: "1",
		username: origin_id
	}, function(e) {
		if (e.err_msg === 'add_contact:added' || e.err_msg === 'add_contact:ok') {
			if (jump_href.indexOf("http") != -1) {
				window.location = jump_href;
			} else {
				WeixinJSBridge.invoke('closeWindow',{},function(res){});
			}
		} else if (e.err_msg === 'add_contact:cancel') {
			alert('必须关注公众号才能上网！');
			go_weixin(origin_id, jump_href);
		} else if (e.err_msg === 'add_contact:fail') {
			alert('关注失败，请检查配置是否正确！');
			go_weixin(origin_id, jump_href);
		} else if (e.err_msg === 'addContact:fail_no permission to execute') {
			setTimeout(function() {
				go_weixin(origin_id, jump_href);
			}, 100);
		}	
	});
}

function get_url_params(src, val){
	var reg = new RegExp("(^|\\?|&)"+ val +"=([^&#]*)(\\s|&|$|#)", "i");
	if (reg.test(src)) return unescape(RegExp.$2); 
	return "";
}

function add_html() {
	var html = document.createElement("h3");
	html.innerHTML = "关注公众号，体验免费Wi-Fi";
	html.style.textAlign = "center";
	document.body.appendChild(html);
}

document.domain = "qq.com";
document.addEventListener("WeixinJSBridgeReady", function () {
	var search = window.location.search,
		origin_id = get_url_params(search, "origin_id"),
		jump_href = get_url_params(search, "jump_href");

	if (typeof origin_id == "undefined" || origin_id == "" || jump_href == "closeWindow") {
		WeixinJSBridge.invoke('closeWindow',{},function(res){});
		return;
	}
	add_html();
	go_weixin(origin_id, jump_href);
});

