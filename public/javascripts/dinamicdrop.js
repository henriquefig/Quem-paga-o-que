  	function dropnum(ini,nro,nome,nomer,id) {
	  	var i=0;
	  	var day=document.createElement('select');
	  	day.name=nomer;
	  	id.appendChild(day);
	  	for(i=ini-1;i<=nro;i++)
	  	{
	  		var option=document.createElement('option');
	  		 day.appendChild(option);              // Create a <li> node
	  		if(i==ini-1)
	  		{			
	  			var textnodeb = document.createTextNode(nome);         // Create a text node
				option.appendChild(textnodeb);
	  			option.selected="selected";
	  		}
	  		else
	  		{
	  			var textnode = document.createTextNode(Math.abs(i));         // Create a text node
				option.appendChild(textnode);    
	  		}
	  		option.value=Math.abs(i);

		}
	}
	function data(valor,i)
	{

		if(valor==1)
		{
	  		var id=document.getElementById('data');
			dropnum(1,31,"day","day",id);
			dropnum(1,12,"month","month",id);
			dropnum(-2005,-1900,"year","year",id);
		}
		else
		{
	  		var id=document.getElementById('data'+i);
			dropnum(1,16,0,"mult"+i,id);
		}
	}