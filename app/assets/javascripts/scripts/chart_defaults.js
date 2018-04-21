/*
 * This is mostly a style function. The style should be defined
 * as jquery parameters because this is the way highcharts library works.
 */
function chart_defaults(title, y_axis_data, placeholder, type)
{
	ret = {
			credits: {
				enabled: false
			},
			chart: {
				renderTo: placeholder,
				type: type,
				spacingRight: 10
			},
			title: {
				text: null,
				style : {
					font: '18px bold',
					color: '#486898',
					padding: '0px 0px 10px 0px'
				}
			},
			xAxis: {
				categories: y_axis_data
			},
			yAxis: {
				title: {
					text : 'Number of words'
				}
			},
			tooltip: {
				formatter: function() {

					if(type == "bar")
						var head = '<b>Current status for all languages</b>';
					else
						var head = '<b>'+ this.x +'</b>';

					var tail = '';
					var translated = false;

					var indexes = this.points.map(function(point){ return point.series.index;});

					if (type == "bar"){
						if(indexes.indexOf(0) != -1){
							untranslated = this.points[indexes.indexOf(0)];
							tail = '<br/>'+ untranslated.series.name +': '+ untranslated.y + tail;
						}
					} else {
						if(indexes.indexOf(0) != -1){
							total = this.points[indexes.indexOf(0)];
							value = total.y
							if(translated)
								value -= translated.y
							head += '<br/>'+ total.series.name +': '+ value;
						}
					}
					return head+tail;

				},
				shared: true,

				backgroundColor: {
					linearGradient: [0, 0, 0, 60],
					stops: [
						[0, '#FFFFFF'],
					[1, '#E0E0E0']
						]
				},
				borderWidth: 2,
				borderColor: null,
				borderRadius: 3,
				style: {
					padding: '12px 25px'
				},
				useHTML: true
			},

			plotOptions: plot_options_for(type),
			legend: {
				reverse: true,
				backgroundColor: '#f8f8f8',
				borderColor: '#e5e5e5',
				borderRadius: 2,
				margin: 20,
				padding: 15,
				symbolPadding: 10,
				symbolWidth: 30,
				itemStyle: {
					cursor: 'pointer',
					margin: 20,
					fontSize: '13px',
					fontWeight: 'bold',
				}
			},

			series:[]
	}
	return ret
}


/* Used on chart_defaults to avoid repetition */
function plot_options_for(type){
	var ret = null;
	if(type == "area"){
		ret = {
			area: {
					lineColor: '#fff',
					lineWidth: 1,
					marker: {
						lineWidth: 2,
						lineColor: '#fff'
					}
				},
				series: {
					lineColor: 'rgba(0,0,0,0.3)',
					lineWidth: 2,
					fillOpacity: 0.9,
					marker: {
						fillColor: null, // inherit from series
						lineWidth: 2,
						lineColor: 'rgba(0,0,0,0.7)',
						radius: 5,
						states: {
							hover: {
								enabled: true,

								fillColor: 'rgba(255,255,255,0.8)',
								lineColor: 'rgba(0,0,0,0.5)'
							}
						}
					}
				}
			}
	} else {
		ret = {
			series: {
				fillOpacity: 0.9,
				borderWidth: 2,
				borderColor: 'rgba(80,80,80,1)',
				borderRadius: 2,
				shadow: false,
				marker: {
					lineWidth: 2,
					lineColor: 'rgba(0,0,0,0.7)',
					radius: 5,
					states: {
						hover: {
							enabled: true,
							fillColor: 'rgba(255,255,255,0.8)',
							lineColor: 'rgba(0,0,0,0.5)'
						}
					}
				}
			}
		}
	}
	return ret;
}


/* Generate a series array as expected by highcharts, with
 * all style need 
 */
function series_for(untranslated, translated, type){
  var translated_color = '#799e3f';
  var untranslated_color = '#9d9d9d';

  var translated_border_color = '#65882e';
  var untranslated_border_color = '#7a7a7a';

	var series = [];
	if(untranslated.filter(Number).length > 0 ){
    untranslated = data_array_to_points(untranslated);
		entry = {
			name: 'Untranslated words',
			data: untranslated,
			stack: 'translate',
			color: untranslated_color,
			borderColor: untranslated_border_color,
      marker: {
        enabled: true
      }
		};

		if(type == "line")
			entry['name'] = 'Content sent to translation';
		series.push(entry);
	}

	if(translated.filter(Number).length > 0){
    translated = data_array_to_points(translated);
		entry = {
			name: 'Translated words',
			data: translated,
			stack: 'translate',
			color: translated_color,
			borderColor: translated_border_color,
      marker: {
        enabled: true
      },
			fillColor: {
				linearGradient: [0, 0, 0, 400],
				stops: [
					[0, 'rgb(165, 203, 100)'],
					[1, 'rgb(91,122,41)']
				]
			}
		};
		if(type == "line")
			entry['name'] = 'Translated content';
		series.push(entry);
	}
	return series;
}


/* This draws the vertical markers on the progress graph. Lines such as deadline, or current day. */
function set_vertical_lines(chart_values, deadlines, deadlines_pair_ids, deadline_target_language, today){
	var lines = [];
	for(var i=0; i< deadlines.length; i++){
		if(today[i]){
			lines.push({
        label: {
          useHTML: true,
          text: 'Today'
        },
				value: i,
				width: 4,
				color: 'rgba(0,0,0,0.6)',
				zIndex: 20,
				dashStyle: 'longdash'
			});
		}
		if(deadlines[i]){
      if(deadline_target_language[i])
        label = "Deadline for " + deadline_target_language[i]
      else
        label = "Deadline"

			lines.push({
        pair_id: deadlines_pair_ids[i],
        label: {
          text: label
        },
				value: i,
				width: 4,
				color: '#EB6565',
				zIndex: 20,
				dashStyle: 'solid',
        events: {
          click: function(ev){
            var pair_id = this.options.pair_id;
            Effect.toggle('boxChangeDeadline', 'appear', {duration: 0.1});
            var x_offset;
            if (ev.pageX -400 > 0)
              x_offset = ev.pageX - 400
            else
              x_offset = ev.pageX + 10
              Element.setStyle('boxChangeDeadline', { left: x_offset + 'px', top: ev.pageY - 50 + 'px'});

            url = '/translation_analytics_language_pairs/edit_deadlines' + '?' + reuse_get_parameters() + "&language_pair_id=" + pair_id;

            $$("input[language_id]:checked").each(function(i){
              url += "&language_pairs[]=" + i.readAttribute('language_id');
            })

            new Ajax.Updater('boxChangeDeadline', url);
          }
        }

			});
		}
	}
	chart_values["xAxis"]["plotLines"] = lines;
	return chart_values;
}


/* This function is used to calculate the distance of the points.
 * Please see the next function for usage
 */
function data_step(data_length){
  var width = window.innerWidth;
  var delta = 0;
  var DATA_POINTS_PER_PX = 200;

  if(data_length * DATA_POINTS_PER_PX > width)
     delta = Math.ceil(data_length * DATA_POINTS_PER_PX / width);

  return delta;
}


/* Given an array with the data to be plot, this function calculates
 * the vertical space that this data will use. It is important to 
 * fill the graph with only 4 points, or to have infinite points one
 * right next to other, giving a better precision to the graph.
 */
function data_array_to_points(data_array){
  points = [];
  /* 
   * Data points should appear accondingly to the screen width 
   */
  var delta = data_step(data_array.length);
  var show_all = delta == 0;

  count = 0;
  data_array.each(function(data){
    // if not showing all dots, show only one for each delta points.
    // The second and argument is to avoid pritning a point too close from the last
    var show_partial = (((count % delta) == 0) && count + delta < data_array.length)
    var last = count == data_array.length -1
    points.push({
      y: data,
      marker: {
        enabled: show_all || show_partial || last
      }
    });
    count += 1;
  });
  return points;
}


/* Helper function to create a query string with the current get parameters */
function reuse_get_parameters(){
   var url = window.location
   var s = url.search.substring(1).split('&');

   if(!s.length)
     return;

   ret = "";
   for(var i  = 0; i < s.length; i++) {
     var parts = s[i].split('=');
     ret += decodeURIComponent(parts[0]) + "=" + decodeURIComponent(parts[1]);
     if(i + 1 < s.length)
       ret += "&"
   }
   return ret
}
