(function(root, undefined) {
	function initTablePage(settings, infodata) {
		this.settings = settings;

		this.infodata = infodata;
		
		this.init = function() {
			this.setLength();
			this.setSearch();
			this.setInfo();
			this.setPage();
		}

		this.setLength = function() {
			var settings	= this.settings,
				infodata	= this.infodata,
				cmdpage		= infodata.cmdpage || "page",
				cmdcount	= infodata.cmdcount || "count",
				count		= infodata.count || 10,
				tableId		= settings.sTableId || null,
				classes		= settings.oClasses,
				setnode		= $(settings.nTableWrapper).find("." + classes.sLength).empty().html("<label/>").children("label");

			var changeHandler = function(settings, val) {
				var len = parseInt(val, 10);
				settings._iDisplayLength = len;
				settings.ajax.url = setUrlParam(settings.ajax.url, cmdpage, 1);
				settings.ajax.url = setUrlParam(settings.ajax.url, cmdcount, len);
				
				myAjaxUpdate(settings, function(d) {
					if (d.r == 0 && typeof d.d.total != "undefined") {
						infodata.total = d.d.total;
						infodata.page = 0;
						infodata.count = len;
					} else {
						infodata.total = 0;
						infodata.page = 0;
						infodata.count = len;
					}
					settings.oApi._fnAjaxUpdateDraw(settings, d);
					var tpage = new initTablePage(settings, infodata);
					tpage.init();
				});
			}
			
			var select = $('<select/>', {
				'name':          tableId + '_length',
				'aria-controls': tableId,
				'class':         classes.sLengthSelect
			});
			
			var menu = settings.aLengthMenu,
				d2 = $.isArray(menu[0]),
				lengths = d2 ? menu[0] : menu,
				language = d2 ? menu[1] : menu;

			for (var i = 0, ien = lengths.length; i < ien; i++) {
				select[0][i] = new Option(language[i], lengths[i]);
			}
			
			setnode.append(settings.oLanguage.sLengthMenu.replace('_MENU_', select[0].outerHTML ))
			$('select', setnode).val(count)
				.on("change", function() {
					changeHandler(settings, count)
				});
		}
		
		this.setSearch = function() {
			var settings	= this.settings,
				infodata	= this.infodata,
				cmdpage		= infodata.cmdpage || "page",
				cmdsearch	= infodata.cmdsearch || "search",
				classes		= settings.oClasses,
				setnode		= $(settings.nTableWrapper).find("." + classes.sFilter).addClass("show").empty().html('<span/>').children('span'),
				input		= '<input type="search" class="input-search ' + classes.sFilterInput + '"/>',
				binput		= '<button type="button" class="button-search btn btn-primary btn-sm">≤È—Ø</button>',
				search		= '<i>'+settings.oLanguage.sSearch+'</i>';

			var inputSearch = function() {
				var val_arr = [],
					html_arr = [],
					sinput = "";

				$(settings.nTable).find("thead th").each(function(index, element) {
					var dsearch = $(element).attr("data-search");
					if (dsearch != "undefined") {
						val_arr.push(dsearch);
						html_arr.push($(element).html());
					}
				});
				
				if (val_arr.length > 0) {
					sinput += "<select class='select-search'>";
					for (var i = 0, ien = val_arr.length; i < ien; i++) {
						sinput += "<option value='" + val_arr[i] + "'>" + html_arr[i] + "</option>";
					}
					sinput += "</select>";
				}
				
				return sinput;
			}

			var searchHandler = function(settings, val) {
				settings.ajax.url = setUrlParam(settings.ajax.url, cmdpage, infodata.page + 1);
				settings.ajax.url = setUrlParam(settings.ajax.url, cmdsearch, val);

				myAjaxUpdate(settings, function(d) {
					if (d.r == 0 && typeof d.d.total != "undefined") {
						infodata.total = d.d.total;
						infodata.page = 0;
						infodata.search = val;

					} else {
						infodata.total = 0;
						infodata.page = 0;
						infodata.search = val;
					}
					settings.oApi._fnAjaxUpdateDraw(settings, d);
					var tpage = new initTablePage(settings, infodata);
					tpage.init();
				});
			}

			input = input + inputSearch();
			search = search.match(/_INPUT_/) ? search.replace('_INPUT_', input) + binput : search + input + binput;
			setnode.append(search);
			$(".button-search", setnode).on("click", function() {
				var val = $(this).closest("div").find(".input-search").val();
				searchHandler(settings, val);
			});
			$(".input-search", setnode).val(infodata.search);
		}
		
		this.setInfo = function() {
			var settings	= this.settings,
				infodata	= this.infodata,
				total		= infodata.total || 0,
				page		= infodata.page || 0,
				count		= infodata.count || 10,
				setnode		= $(settings.nTableWrapper).find("." + settings.oClasses.sInfo);

			var strs = settings.oLanguage.sInfo.replace(/_START_/g, (page * count + 1) <= total ? (page * count + 1) : total)
											   .replace(/_END_/g,	((page + 1) * count) <= total ? ((page + 1) * count) : total)
											   .replace(/_TOTAL_/g, total);

			setnode.html(strs);
		}
		
		this.setPage = function() {
			var settings		= this.settings,
				infodata		= this.infodata,
				tableId			= settings.sTableId || null,
				classes 		= settings.oClasses,
				lang			= settings.oLanguage.oPaginate,
				total			= parseInt(infodata.total) || 0,
				page			= parseInt(infodata.page) || 0,
				count			= parseInt(infodata.count) || 10,
				ccmd			= infodata.cmdpage || "page",
				pages			= Math.ceil(total / count),
				btnDisplay		= "",
				btnClass		= "",
				counter			= 0,
				buttons 		= _numbers(page, pages),
				setnode			= $(settings.nTableWrapper).find(".dataTables_paginate").empty().html('<ul class="pagination"/>').children('ul');

			var clickHandler = function (e) {
				var opage = page;
				var npage = e.data.action;
				e.preventDefault();

				if (!$(e.currentTarget).hasClass('disabled') && opage != npage) {
					if (npage == "first") {
						npage = 0;
					} else if (npage == "previous") {
						npage = parseInt(opage) - 1;
					} else if (npage == "next") {
						npage = parseInt(opage) + 1;
					} else if (npage == "last") {
						npage = pages - 1;
					} else if (npage == "ellipsis") {
						return;
					}

					settings.ajax.url = setUrlParam(settings.ajax.url, ccmd, npage + 1);
					myAjaxUpdate(settings, function(d) {
						if (d.r == 0 && typeof d.d.total != "undefined") {
							infodata.total = d.d.total;
							infodata.page = npage;
						} else {
							infodata.total = 0;
							infodata.page = 0;
						}
						settings.oApi._fnAjaxUpdateDraw(settings, d);
						var tpage = new initTablePage(settings, infodata);
						tpage.init();
					});
				}
			}

			for (var i = 0, ien = buttons.length; i < ien; i++) {
				var button = buttons[i];
				
				switch (button) {
					case 'ellipsis':
						btnDisplay = '&#x2026;';
						btnClass = 'disabled';
						break;

					case 'first':
						btnDisplay = lang.sFirst;
						btnClass = button + (page > 0 ? '' : ' disabled');
						break;

					case 'previous':
						btnDisplay = lang.sPrevious;
						btnClass = button + (page > 0 ? '' : ' disabled');
						break;

					case 'next':
						btnDisplay = lang.sNext;
						btnClass = button + (page < pages - 1 ? '' : ' disabled');
						break;

					case 'last':
						btnDisplay = lang.sLast;
						btnClass = button + (page < pages - 1 ? '' : ' disabled');
						break;

					default:
						btnDisplay = button + 1;
						btnClass = page === button ?
							'active' : '';
						break;
				}
				
				if (btnDisplay) {
					var node = $('<li>', {
								'class': classes.sPageButton + ' ' + btnClass,
								'id': tableId + '_' + button
							})
							.append($('<a>', {
									'href': '#',
									'aria-controls': tableId,
									'data-dt-idx': counter
								})
								.html(btnDisplay))
							.appendTo(setnode);

					settings.oApi._fnBindAction(
						node, {action: button}, clickHandler
					);

					counter++;
				}
			}
		}
	}
	
	function _range(len, start) {
		var out = [];
		var end;
	
		if ( start === undefined ) {
			start = 0;
			end = len;
		} else {
			end = start;
			start = len;
		}
	
		for (var i = start; i < end; i++) {
			out.push(i);
		}
	
		return out;
	};
	
	function _numbers(page, pages) {
		var arr = ['first', 'previous'],
			numbers = [],
			buttons = 7,
			half = Math.floor(buttons / 2),
			i = 1;
	
		if (pages <= buttons) {
			numbers = _range(0, pages);
		} else if (page <= half) {
			numbers = _range(0, buttons - 2);
			numbers.push('ellipsis');
			numbers.push(pages - 1);
		} else if (page >= pages - 1 - half) {
			numbers = _range(pages - (buttons - 2), pages);
			numbers.splice(0, 0, 'ellipsis');
			numbers.splice(0, 0, 0);
		} else {
			numbers = _range(page - half + 2, page + half - 1);
			numbers.push('ellipsis');
			numbers.push(pages - 1);
			numbers.splice(0, 0, 'ellipsis');
			numbers.splice(0, 0, 0);
		}
		
		for (var i = 0, ien = numbers.length; i < ien; i++) {
			arr.push(numbers[i]);
		}
		arr.push("next");
		arr.push("last");
		
		return arr;
	}
	
	function myAjaxUpdate(settings, fn) {
		if (settings.bAjaxDataGet) {
			settings.iDraw++;
			settings.oApi._fnProcessingDisplay(settings, true);
			settings.oApi._fnBuildAjax(
				settings,
				// settings.oApi._fnAjaxParameters(settings),
				{},
				fn
			);
			return false;
		}
		return true;
	}

	root.initTablePage		= initTablePage;
})(this);
