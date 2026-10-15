fetch("/api/info").then(r=>r.json()).then(i=>{document.getElementById("s").textContent="Server is running on "+i.hostName})
