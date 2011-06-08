
function spawn_map(elmt,center, zoom) {
    var myOptions = {
      zoom: zoom,
	center: center,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };

    return new google.maps.Map(document.getElementById(elmt),
        myOptions);
}

var flood_map = null;
var torn_map = null;
var epa_map = null;
var hur_map = null;
var nuke_map = null;

function build_content_div(contentp,header,map_id) {
    var content = $("#" + contentp)
    var content_html = content.html();

    var infobox_tmpl = null;

    if (map_id != undefined) {
	infobox_tmpl =
	'<div class="infobox collapse" id="' + contentp + '">'+ 
	'<div class="header"><div style="float:left"><h2>' + header + '</h2></div><div class="spinner" style="float:right;"><img id="img-spinner" src="media/spinner.gif" alt="Loading"/></div></div>' +
	'<div style="width:70%; float: left">' + content_html + '</div>' +
	'<div id="' + map_id + '" style="width:30%; height:200px; float: right"></div>' +
	    '<div style="clear: both"></div>' +  
	'</div>'
    } else {
	infobox_tmpl =
	'<div class="infobox collapse" id="' + contentp + '">' +
	'<div class="header"><h2>' + header + '</h2><img id="img-spinner" src="media/spinner.gif" alt="Loading"/></div>' +
	'<div style="width:100%; float: left">' + content_html + '</div>' +
	'<div style="clear:both"></div>' +
	'</div>'
    }	

    infobox_tmpl = infobox_tmpl + '<div style="clear:both"></div>';
	
    $.subscribe("/update/" + contentp, function( event ) {
	$("#" + contentp + " .spinner").remove();
	$("#" + contentp).removeClass("collapse");
	$(".main").removeClass("height");
    });

    content.remove();
    $("#infoboxes").append(infobox_tmpl);
}

function decode_loss(loss) {
    if (loss < 1) {
	return "<$50";
    } else {
	return ">$50";
    }
}

$(function() {
    $.subscribe("/update/nuke_content", function( content ) {
	var jq = $("#nuke_content .replace");
	jq.html(jq.html().replace("_num_", content.length).replace("_radius_","50 miles"));
	
	var tbl = $("#nuke_content table");
	$.map(content, function( nuke ) {
	    tbl.append("<tr><td> " + nuke.name + "</td><td>" + nuke.lat + "</td><td> " + nuke.lon + "</td></tr>");
	});
	if (content.length == 0) {
	    tbl.append("<tr><td style=\"text-align: center;\" colspan=\"3\">No Nuclear Facilities Found</td></tr>");
	}

    });
    $.subscribe("/update/torn_content", function( content ) {
	var jq = $("#torn_content .replace");
	jq.html(jq.html().replace("_num_", content.length).replace("_radius_","50 miles"));
	
	var tbl = $("#torn_content table");
	$.map(content, function( torn  ) {
	    tbl.append("<tr><td>" + torn.date + "</td>" +
		       "<td>" + torn.f + "</td>" + 
		       "<td>" + decode_loss(torn.loss) + "</td>" +
		       "<td>" + torn.lat + "</td>" +
		       "<td>" + torn.lon + "</td></tr>");
	});
    });

    $.subscribe("/update/flood_content", function( content ) {
	var jq = $("#flood_content .replace");
	jq.html(jq.html().replace("_zone_", content.attr.FLD_ZONE));
    });

    $.subscribe("/update/epa_content", function( content ) {
	var jq = $("#epa_content .replace");
	jq.html(jq.html().replace("_num_", content.length).replace("_radius_","3/4 miles"));

	var count = 0;
	var thresh = 5;
	var style = "";

	var tbl = $("#epa_content table");
	$.map(content, function( epa  ) {
	    if (count >= thresh) {
		style = 'class="hideme epa_hidden"'
	    }

	    tbl.append("<tr " + style + "><td><a href=\"" + epa.url + "\">" + epa.name + "</a></td>" +
		       "<td>" + epa.code + "</td>" +
		       "<td>" + epa.lat + "</td>" +
		       "<td>" + epa.lon + "</td></tr>");
	    count = count + 1;
	});

	if (count > thresh) {
	    $("#show_epa").append("Show " + (count - thresh) + " additional facilities");
	} else {
	    $("#show_epa").remove();
	}

	$.subscribe("/show/epa", function() {
	    $(".epa_hidden").each(function() {
		$(this).removeClass("hideme");
	    });
	});

    });
});
 
  function initialize(center) {
      flood_map = spawn_map("flood_map",center,10);
      torn_map = spawn_map("torn_map",center,7);
      epa_map = spawn_map("epa_map",center,13);
      hur_map = spawn_map("hur_map",center,2);
      nuke_map = spawn_map("nuke_map",center,7);
  }

  URL = "http://api.adamhinz.com/"

function create_content() {
    build_content_div("nuke_content","Nuclear Reactors","nuke_map");
    build_content_div("torn_content","Tornados","torn_map");
    build_content_div("epa_content","Facilities Handling Hazardous Materials","epa_map");
    build_content_div("flood_content","Flood Information","flood_map");
    build_content_div("hur_content","Hurricane Paths (1995 to 2010)","hur_map");
    build_content_div("quake_content","Earthquake Risk");
}

  $(function() {
      var address = $.url().param("address");
      var latlng = null;

      create_content();

      $.ajax({
          url: URL + "geocode",
	  dataType: 'jsonp',
	  data: {
	      address: address
	  },
	  success: function( ll ) {
	      latlng = new google.maps.LatLng(ll.lat, ll.lon);
	      initialize(latlng);	 
	      process();
	  }
      });     


      function process() {
	  /*
	  $.ajax({
	      url: "http://localhost:4566/earthquakes/area",
	      dataType: 'jsonp',
	      data: {
		  lat_min: 37.959409,
		  lat_max: 42.195969,
		  lon_min: -81.430664,
		  lon_max: -72.168945
	      },
	      success: function(json) {
		  $.map(json, function( eq_square ) {
		      lat = eq_square.lat;
		      lon = eq_square.lon;

		      var ll1 = new google.maps.LatLng(lat,lon)
		      var ll2 = new google.maps.LatLng(lat + 0.05,lon)
		      var ll3 = new google.maps.LatLng(lat + 0.05,lon + 0.05)
		      var ll4 = new google.maps.LatLng(lat,lon + 0.05)		     

		      var color = "#0000" + (255.0 * eq_square.val / eq_square.max).toString(16)

		      new google.maps.Polygon({
			  paths: [ll1,ll2,ll3,ll4], 
			  strokeColor: color,
			  strokeOpacity: 0.0,
			  strokeWeight: 2,
			  fillColor: color,
			  fillOpacity: 0.2,
			  map: map
		      });

		  });
	      }
	  });
*/
	  $.ajax({
	      url: URL + "hurricanes",
	      dataType: 'jsonp',
	      data: {
		  address: address
	      },
	      success: function(json) {
		  $.map(json, function( hurricane ) {
		      var path = $.map(hurricane.path, function( ll ) {
			  var lls = ll.split(",");
			  return new google.maps.LatLng(lls[0],lls[1]);
		      });

		      new google.maps.Polyline({
			  strokeColor: '#00ff00',
			  strokeOpacity: 1.0,
			  strokeWeight: 3,
			  map: hur_map,
			  path: path
		      });
		  });

		  $.publish("/update/hur_content",[]);
	      }
	  });

	  $.ajax({
	      url: URL + "tornados",
	      dataType: 'jsonp',
	      data: {
		  address: address
	      },
	      success: function(json) {
		  $.map(json, function( ll ) {
		      var myLatLng = new google.maps.LatLng(ll.lat,ll.lon);
		      var marker = new google.maps.Marker({
			  position: myLatLng, 
			  map: torn_map, 
			  icon: "http://www.google.com/intl/en_us/mapfiles/ms/micons/blue-dot.png",
			  title: "Nuclear Power Plant: " + json.title + "(" + json.type + ")"
		      });  
		  });

		  $.publish("/update/torn_content",[json]);
	      }
	  });
		      
	  $.ajax({
	      url: URL + "flood",
	      dataType: 'jsonp',
	      data: {
		  address: address
	      },
	      success: function(json) {
		  $.map(json.geo, function( polygon ) {
		      var gmap = $.map(polygon, function( ar ) {
			  var pts = ar.split(" ")
			  return new google.maps.LatLng(pts[1],pts[0]);
		      });

		      new google.maps.Polygon({
			  paths: gmap, 
			  strokeColor: "#FF0000",
			  strokeOpacity: 0.8,
			  strokeWeight: 2,
			  fillColor: "#FF0000",
			  fillOpacity: 0.35,
			  map: flood_map
		      });
		  });

		  $.publish("/update/flood_content",[]);
	      }
	  });


	  $.ajax({
	      url: URL + "epa",
	      dataType: 'jsonp',
	      data: {
		  address: address
	      },
	      success: function(json) {
		  $.map(json, function( epa ) {
		      var myLatLng = new google.maps.LatLng(epa.lat,epa.lon);
		      var marker = new google.maps.Marker({
			  position: myLatLng, 
			  map: epa_map, 
			  title: "Nuclear Power Plant: " + json.title + "(" + json.type + ")",
			  icon: "http://www.google.com/intl/en_us/mapfiles/ms/micons/green-dot.png"
		      });  
//
		  });

		  $.publish("/update/epa_content",[json]);
	      }
	  });

	  $.ajax({
	      url: URL + "hazards",
	      dataType: 'jsonp',
	      data: {
		  address: address
	      },
	      success: function(json) {
		  $.map(json, function( powerplant ) {
		      var myLatLng = new google.maps.LatLng(powerplant.lat,powerplant.lon);
		      var marker = new google.maps.Marker({
			  position: myLatLng, 
			  map: nuke_map, 
			  title: "Nuclear Power Plant: " + json.name
		      });  
//
		  });		  

		  $.publish("/update/nuke_content",[json]);
	      }
	  });
      }
  });
