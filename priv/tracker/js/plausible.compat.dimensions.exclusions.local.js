!function(){"use strict";var e,t,i,l=window.location,p=window.document,s=p.getElementById("plausible"),u=s.getAttribute("data-api")||(e=s.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),w=s&&s.getAttribute("data-exclude").split(",");function d(e){console.warn("Ignoring Event: "+e)}function n(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"===window.localStorage.plausible_ignore)return d("localStorage flag")}catch(e){}if(w)for(var i=0;i<w.length;i++)if("pageview"===e&&l.pathname.match(new RegExp("^"+w[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return d("exclusion rule");var n={};n.n=e,n.u=l.href,n.d=s.getAttribute("data-domain"),n.r=p.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=t.props);var a=s.getAttributeNames().filter(function(e){return"event-"===e.substring(0,6)}),r=n.p||{};a.forEach(function(e){var t=e.replace("event-",""),i=s.getAttribute(e);r[t]=r[t]||i}),n.p=r;var o=new XMLHttpRequest;o.open("POST",u,!0),o.setRequestHeader("Content-Type","text/plain"),o.send(JSON.stringify(n)),o.onreadystatechange=function(){4===o.readyState&&t&&t.callback&&t.callback()}}}var a=window.plausible&&window.plausible.q||[];window.plausible=n;for(var r,o=0;o<a.length;o++)n.apply(this,a[o]);function c(){r!==l.pathname&&(r=l.pathname,n("pageview"))}var g,v=window.history;v.pushState&&(g=v.pushState,v.pushState=function(){g.apply(this,arguments),c()},window.addEventListener("popstate",c)),"prerender"===p.visibilityState?p.addEventListener("visibilitychange",function(){r||"visible"!==p.visibilityState||c()}):c()}();