$.fn.dataTableExt.oApi.fnReloadAjax = function ( oSettings, sNewSource, aData, fnCallback, bStandingRedraw )
{
    if ( typeof sNewSource != 'undefined' && sNewSource != null ) {
        oSettings.sAjaxSource = sNewSource;
    }
 
    // Server-side processing should just call fnDraw
    if ( oSettings.oFeatures.bServerSide ) {
        this.fnDraw();
        return;
    }
 
    this.oApi._fnProcessingDisplay( oSettings, true );
    var that = this;
    var iStart = oSettings._iDisplayStart;
  
    this.oApi._fnServerParams( oSettings, aData );
      
    oSettings.fnServerData.call( oSettings.oInstance, oSettings.sAjaxSource, aData, function(json) {
        /* Clear the old information from the table */
        that.oApi._fnClearTable( oSettings );
          
        /* Got the data - add it to the table */
        var aData =  (oSettings.sAjaxDataProp !== "") ?
            that.oApi._fnGetObjectDataFn( oSettings.sAjaxDataProp )( json ) : json;
          
        for ( var i=0 ; i<aData.length ; i++ )
        {
            that.oApi._fnAddData( oSettings, aData[i] );
        }
          
        oSettings.aiDisplay = oSettings.aiDisplayMaster.slice();
          
        if ( typeof bStandingRedraw != 'undefined' && bStandingRedraw === true )
        {
            oSettings._iDisplayStart = iStart;
            that.fnDraw( false );
        }
        else
        {
            that.fnDraw();
        }
          
        that.oApi._fnProcessingDisplay( oSettings, false );
          
        /* Callback user function - for event handlers etc */
        if ( typeof fnCallback == 'function' && fnCallback != null )
        {
            fnCallback( oSettings );
        }
    }, oSettings );
};

//datatable隐藏列
$.fn.extend({
	oDtHideColumn: function(oDt, hd) {
		var that = this;
		var node = oDt.fnGetNodes();
		var last = [];
		
		for (var i in hd) {
			$(that).find('tr:eq(0) td').each(function(index, element) {
				if($(element).attr('colid') == hd[i]) {
					last.push(index);
				};
			});
		}
		
		$(that).find('tr:eq(0) td').css('display', 'table-cell');
		for (var m = node.length - 1; m >= 0; m--) {
			$(node[m]).find('td').css('display', 'table-cell');
		}
		
		for (var k in last) {
			$(that).find('tr:eq(0) td:eq('+ last[k] +')').css('display', 'none');
			for (var n = node.length - 1; n >= 0; n--) {
				$(node[n]).find('td:eq('+ last[k] +')').css('display', 'none');
			}
		}
	}
});

!function(root){
	//dtReload(oTable, "../q", {"cmd" : cmd});
    function dtReload(oDt, sUrl, aData) {
        oDt.fnReloadAjax(sUrl, aData);
    }
    function dtReloadData(oDt, aaData, keepPage, oFun) {
		if (objCountLength(aaData) == 0) {
			oDt.fnClearTable(true);
			return;
		}
        var oSetting = oDt.fnSettings();
        var page = oSetting._iDisplayStart / oSetting._iDisplayLength;
        oDt.fnClearTable(true);
        oDt.fnAddData(aaData, true);
		//过滤
		if (oFun && typeof oFun == 'function') {
			oFun();
		}
        if (keepPage != 'undefined' && keepPage) {
            oDt.fnPageChange(page);
        };
    }

    function dtGetSelected(oDt) {
        var dRows = new Array();
        var rs = oDt.fnGetNodes();
        for (var i = rs.length - 1; i >= 0; i--) {
            if($(rs[i]).hasClass('row_selected')){
                dRows.push(oDt.fnGetData(rs[i]));
            }
        };
        return dRows;
    }

    function dtSelectAll(oDt, currentPage) {
        var rs = oDt.fnGetNodes();
        var opt = oDt.fnSettings();
        if (currentPage) {
            oDt.find('tbody tr').each(function(index){
                var row = $(this);
                var check = false;
				if ($(this).find('td input[type="checkbox"]').attr('disabled') == 'disabled') return true;
                row.toggleClass('row_selected');
                if (row.hasClass('row_selected')) {
                    check = true;
                };
                row.find('td input[type="checkbox"]').attr('checked', check);
            });
        }else{
            for (var i = rs.length - 1; i >= 0; i--) {
                var check = false;
				if ($(rs[i]).find('td input[type="checkbox"]').attr('disabled') == 'disabled') continue;
                $(rs[i]).toggleClass('row_selected');
                if ($(rs[i]).hasClass('row_selected')) {
                    check = true;
                };
                $(rs[i]).find('td input[type="checkbox"]').attr('checked', check);
            };
        }
        
    }

    function row_select_event(){
        var tr = $(this).closest('tr');
        $(tr).toggleClass("row_selected")
        if($(tr).hasClass('row_selected'))
            $(tr).find('td input[type="checkbox"]').attr('checked', true);
        else
            $(tr).find('td input[type="checkbox"]').attr('checked', false);
    };

    function dtBindRowSelectEvents(row) {
        var otable = this;
        $(row).find('td input[type="checkbox"]').unbind('click', row_select_event);
        $(row).find('td input[type="checkbox"]').bind('click', row_select_event);
    }

    function ObjectToArray(o) {
        var aar = new Array();
        var i = 0;
        for ( key in o ) {
            if (typeof(o[key])=='object') {
                if(!o[key].Name){
                    o[key].Name = key;
                    o[key].aaIndex = i++;
                }
            }else{
                var temp = o[key];
                o[key] = {};
                o[key].Name = key;
                o[key].Value = temp;
                o[key].aaIndex = i++;
            }
            aar.push(o[key]);
        }
        return aar;
    }
	
	function dtPageChange(url, table){
		var tab = oTable
        if (typeof table != 'undefined' ) {
            tab = table
		}
		
		var _oSettings = tab.fnSettings();
		page = _oSettings._iDisplayStart / _oSettings._iDisplayLength;
		
		tab.fnReloadAjax(url, null, function(){
			tab.fnPageChange(page);
		})
	}
	function _dtPageChange(oDt, sUrl, aData ){
		var _oSettings = oDt.fnSettings();
		page = _oSettings._iDisplayStart / _oSettings._iDisplayLength;
		oDt.fnReloadAjax(sUrl,aData,function(){
			oDt.fnPageChange(page);
		})
	}
	
	//获取过滤的字符
	function GetRequestFilter() {
		var reStr = '',
			url = window.location.href,
			urls = url.substring(url.lastIndexOf('?')),
			theRequest = new Object();
		if (urls.indexOf("?") != -1) {
			var str = urls.substr(1);
			strs = str.split("&");		//array
			for(var i = 0; i < strs.length; i ++) {
				theRequest[strs[i].split("=")[0]]= (strs[i].split("=")[1]);
			}
			if (theRequest.filter) {
				reStr = theRequest.filter.split("||");
				reStr = reStr.join(" ");
			}
		}
		return reStr;
	}
	
	//当前URL
	var urlFilterString = window.location.href;
	urlFilterString = urlFilterString.substring(0, urlFilterString.lastIndexOf('?'));
	urlFilterString = urlFilterString.substring(0, urlFilterString.lastIndexOf('/')+1);


    //赋值到 windows 对象
    root.dtReload = dtReload;
    root.dtReloadData = dtReloadData;
    root.dtGetSelected = dtGetSelected;
    root.dtBindRowSelectEvents = dtBindRowSelectEvents;
	root.dtPageChange = dtPageChange;
	root._dtPageChange = _dtPageChange
    root.ObjectToArray = ObjectToArray;
    root.dtSelectAll = dtSelectAll;
	root.GetRequestFilter = GetRequestFilter;
	root.urlFilterString = urlFilterString;
}(this);