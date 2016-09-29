# Janeiro de 2016
# Henrique Figueiredo

package DespesasRinte;
#!/usr/bin/perl
use strict;
use warnings;
use Dancer2;
use Dancer2::Plugin::Email;
use Hash::MultiValue;
use diagnostics;
use DBI;
our $VERSION = '0.1';
use SVG;
use POSIX qw(strftime);

# começar sessão
set session => 'Simple'; 
# mensagens para email
my $message="O teu registo na platforma QPO está a um passo de estar completa, por favor clique aqui para activar a sua conta:\nhttp://localhost:5000/activate?email=";
my $subject="Registo QPO!";

# conexão à base de dados
sub connect_db{

	my $dbh=DBI->connect(
		"DBI:mysql:database=QPO;host=localhost",
		"root",
		"root"
		) || die "Error connecting to database: $!\n";
	return $dbh;
}

# cabeçalhos das paginas
sub prepare_html{
	my $array="<html>\n<head><link rel=\"shortcut icon\" href=\"/images/favicon.ico\"><title>QPO?</title>\n<link rel=\"stylesheet\" href=\"/css/style.css\">\n</head><body><div id=header><img align=right src=\"/images/qpo.png\"  width=\"100\" height=\"100\"/>\n<h1 align=center>\nQuem paga o quê?!\n</h1>\n<a href=\"/login\"><img src=\"/images/home.jpeg\"  alt=\"HOME\" padding=\"none\" height=\"45\"></a>\n";
	$array.="<script type=\"text/javascript\"  src=\"/javascripts/dinamicdrop.js\"></script>\n<script type=\"text/javascript\"  src=\"/javascripts/valida.js\"></script>";
	if(session('email') ne "")
	{
		if(session('email') eq "johncenaff\@gmail.com")
		{
			$array.="<embed src=\"jc.mp3\" autostart=false loop=\"infinite\" hidden=true>";
		}
		$array .="<a href=\"/MinhasListas\"><img src=\"/images/list.png\"  alt=\"MinhasListas\" padding=\"none\" height=\"45\" width=\"45\"></a>\n</div>\n<div id=nav>\n<h3 align=center>";
		if(session('email') eq "johncenaff\@gmail.com")
		{
			$array .= "Parabéns és o <br>".session('Fnome')." ".session('Lnome');
		}
		else
		{
			$array .= "Bem-vindo <br>".session('Fnome')." ".session('Lnome')." <a href=\"/altperfil\"><img src=\"/images/edit.png\"  alt=\"editp\" padding=\"none\" height=\"20\"></a>";
		}
		if(session('SU') eq "1")
		{
			$array .="<br>Privilégios de Administrador<br>Listar <a href=./lista>Users</a>";
		}
		$array .="</h3>\n<br>\n<a align=center href=./logout>Logout</a>\n";
	}

	return $array."\n</div>\n";
}	

# footer das páginas
sub prepare_html2{
	my $array="\n<div id=footer> Copyright Henrique Figueiredo </div>\n</body>\n</html>";
	return $array;
}
# envia emails do endereço "QPO@figapp.pt"
sub emails{
 	email {
 			sender  => 'QPO',
            from    => "QPO\@figapp.pt",
            to      => $_[0],
            subject => $_[2],
            body    => $_[1],
        };

};

# confirmaçãodo login
sub login{
	my $dbh=connect_db();
	my $query="SELECT Users.Nro_User,Users.F_name,Users.L_name,
	Users.Email,Users.SU,Users.Verificado,Users.Existente FROM Users;";

	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $counter=1;
	# Tabela Users SQL para referencia
	# 	|	0	  |		1  |	2	|	3	| 4  |		5	  |		6	  |
	#  | Nro_User | F_name | L_name | Email | SU | Verificado | Existente |
	while (my $ref = $sth->fetchrow_arrayref())
	{
		if($ref->[3] eq session('email'))
		{
			$counter++;
			if($ref->[5] eq "1")
			{
				if($ref->[6] eq "1")
				{
					
					# Tabela Autenticacao SQL para referencia
					#  |	0	  |		1   |
					#  | Nro_User | Password|
					my $query="SELECT Autenticacao.Password FROM Autenticacao Where Nro_User=".$ref->[0].";";
					my $sth2 = $dbh->prepare($query);
					$sth2->execute();
					my $ref2 = $sth2->fetchrow_arrayref();
					if($ref2->[0] eq session('password'))
					{
						app->destroy_session;
						# Verificar Super User
						if($ref->[4] eq "1")
						{
							session "SU" => "1";
						}
						else
						{
							session "SU" => "0";
						}
						# iniciar sessao
						session "email" => $ref->[3];
						session "Nro_user" => $ref->[0];
						session "Fnome" =>	$ref->[1];
	     				session "Lnome" => $ref->[2];
	   					redirect $_[0];
	   				}
	   				else
	   				{
						$counter=1;
					}
	   			}
   			}

		}
	}
	if($counter==1)
	{
		app->destroy_session;
	}
};
# função especial para criar string dos pagantes de determinado produto
sub stringarPagantes{
	my $res;
	my $dbh=connect_db();
	foreach my $val (@_)
	{
		my @array=split('x',$val);

		# Tabela Users SQL para referencia
		# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
		#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
		my $query="SELECT * FROM Users WHERE Nro_User=".$array[1].";";
		my $sth2 = $dbh->prepare($query);
		$sth2->execute();
		my $ref2 = $sth2->fetchrow_arrayref();
		if($array[0]!=0)
		{
			$res.=$ref2->[1]." x";
			$res.=$array[0].", ";
		}
  	}
  	return $res;
};
# inserir compra em lista
sub insersaolist{
	my @cadapaga=split(',',$_[1]);	
	my $div=0;
	my $dbh=connect_db();
	foreach my $val (@cadapaga) 
	{
		my @mult=split('x',$val);
		$div=$div+$mult[0];
	}
	foreach my $val (@cadapaga) 
	{
		my @mult=split('x',$val);
		my $saldo;

		# Tabela Lista SQL para referencia
		#  |	0	  |		1  |	2	|	3	| 	4	  |
		#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
		my $query="SELECT * FROM Listas WHERE Nro_list=".$_[0]." AND Nro_User=".$mult[1].";";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my $ref = $sth->fetchrow_arrayref();
		if(session('Nro_user') ne $mult[1])
	  	{
	  		$saldo=$ref->[2]-($_[2]*100*$mult[0])/$div;

		# Tabela Users SQL para referencia
		# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
		#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
		  	$query="SELECT * FROM Users WHERE Nro_User=".$mult[1].";";
			my $sth2 = $dbh->prepare($query);
			$sth2->execute();
			my $ref2 = $sth2->fetchrow_arrayref();
			# verificar se tem os alertas activos
			if($ref2->[9] == 1) 
			{
				if($saldo < 0)
				{
					# enviar email com aviso de mudança de saldo
					my $ssa=($saldo/100);
					$message="Olá ".$ref2->[1]." ".$ref2->[2]."!\nFoi submetido uma nova compra na lista ".$ref->[3]." que deixou o teu saldo negativo.\nSaldo: " .$ssa."€ .\n Podera ver as mudanças aqui:\nhttp://localhost:5000/MinhasListas";
					$subject="QPO Alerta: Saldo negativo";
					emails($ref2->[3],$message,$subject);
				}
			}
	  	}
	  	else
	  	{
	  		# descontar o valor da compra ao saldo
	  		$saldo=$ref->[2]+($_[2]*100-($_[2]*100*$mult[0])/$div);
	  	}

		# Tabela Lista SQL para referencia
		#  |	0	  |		1  |	2	|	3	| 	4	  |
		#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
	  	$query="UPDATE Listas SET Saldo=".$saldo." WHERE Nro_list=".$_[0]." AND Nro_User=".$mult[1].";";
		my $sth3 = $dbh->prepare($query);
		$sth3->execute();
  	}
};
get '/' => sub {
	redirect '/login';
};
# logout button
get '/logout' => sub {
	app->destroy_session;
	redirect '/login';
};
# alterar perfil
get '/altperfil' => sub {
	if(session('email') eq "")
	{
		redirect '/login';
	}
	else
	{
		my $array=prepare_html();
		my $dbh=connect_db();
		my $op=param('op');
		if($op)
		{
			my $pname=param('pname');
			my $lname=param('lname');
			my $date=param('date');
			my $city=param('city');
			my $up=param('updados');
			my $alt=param('alert');

			# Tabela Users SQL para referencia
			# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
			#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
			my $query="UPDATE Users SET F_name='".$pname."', L_name='".$lname."', Bday='".$date."', City='".$city;
			if($up eq "update")
			{
				$query.="', Updates=1";
			}
			else
			{
				$query.="', Updates=0";
			}
			if($alt eq "alert")
			{
				$query.=", Alert=1";
			}
			else
			{
				$query.=", Alert=0";
			}
			$query.=" WHERE Nro_User=".session('Nro_user').";";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			$array.="<b>Perfil actualizado com sucesso!</b>";

		}
		my $query2="SELECT * FROM Users WHERE Nro_User=".session('Nro_user').";";
		my $sth2 = $dbh->prepare($query2);
		$sth2->execute();
		my $ref = $sth2->fetchrow_arrayref();
		$array .="<form>\nPrimeiro Nome:<input type=text name=\"pname\" value=\"".$ref->[1]."\"><br>\nUltimo Nome:<input type=text name=\"lname\" value=\"".$ref->[2]."\"><br>\nData de nascimento:<input type=date name=\"date\" value=\"".$ref->[4]."\"><br>Cidade:<input type=text name=\"city\" value=\"".$ref->[6]."\"><br>";
		$array .="<input type=\"checkbox\" name=\"updados\" value=\"update\"";
		if($ref->[8] eq "1")
		{
			$array.=" checked";
		}
		$array .=">Sim pretendo receber updates quando o meu saldo for alterado.<br><input type=\"checkbox\" name=\"alert\" value=\"alert\"";
		if($ref->[9] eq "1")
		{
			$array.=" checked";
		}
		$array .=">Sim pretendo receber alertas quando o meu saldo for inferior a 0.<br><input type=\"submit\" value=\"Alterar dados pessoais\" name=\"op\">\n</form>";
		$array .= prepare_html2();
		return $array;

	}
};
# pagina do administrador que lista todos os outros utilizadores
get '/lista' => sub {
	if(session('SU') eq "1")
	{
		my $array = prepare_html();
		$array .= "<br><h2 align=center>Utilizadores</h2><table align=center border=\"1\" style=\"width:75%\">\n";
		my $query;
		my $dbh=connect_db();
		my $op=param('Del');
		if($op)
		{	

		# Tabela Users SQL para referencia
		# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
		#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
			$query="SELECT * FROM Users WHERE Verificado=0";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			# Super User pode eliminar utilizadores não verificados
			while (my $ref2 = $sth->fetchrow_arrayref())
			{
				$query="DELETE FROM Autenticacao WHERE Nro_User=".$ref2->[0].";";
				my $sth2 = $dbh->prepare($query);
				$sth2->execute();
				$query="DELETE FROM Users WHERE Nro_User=".$ref2->[0].";";
				my $sth3 = $dbh->prepare($query);
				$sth3->execute();
			}
			$array .="<h3 align=center><b>Utilizadores não validados eliminados com sucesso!</b></h3>";
		}
		$query="SELECT * FROM Users;";
		my $sth3 = $dbh->prepare($query);
		$sth3->execute();
		$array .="<tr><td>Número</td>\n<td>Primeiro Nome</td>\n<td>SobreNome</td>\n<td>Email</td><td>Data de nascimento</td>\n<td>Sexo</td>\n<td>Cidade</td>\n<td>SU</td>\n<td>Updates</td>\n<td>Alertas</td>\n<td>Verificado</td>\n<td>Existente</td>\n</tr>\n";
		while (my $ref = $sth3->fetchrow_arrayref())
		{
			$array .="<tr><td><input type=\"submit\" nome='nro' value=".$ref->[0]."></td>\n<td>".$ref->[1]."</td>\n<td>".$ref->[2]."</td>\n<td>".$ref->[3]."</td>\n<td>".$ref->[4]."</td>\n<td>";
			if($ref->[5] eq "1")
			{
				$array.="F";
			}
			else
			{
				$array.="M";
			}
			$array.="</td>\n<td>".$ref->[6];
			for(my $i=7;$i<=11;$i++)
			{
				if($ref->[$i] == 0)
				{
					$array.="</td>\n<td>Não";
				}
				else
				{
					$array.="</td>\n<td>Sim";
				}
			}
			$array .= "</td>\n</tr>\n";
		}
		$array .= "</table><form align=\'center\'><input type=submit name=Del value=Eliminar_Não_Validados>\n</form>";
		$array .= prepare_html2();
		return $array;
	}
	else
	{
		redirect '/MinhasListas';
	}
};
# página de registo
any ['get','post'] => '/register' => sub {
	if(session('email') ne "")
	{
		redirect '/MinhasListas';
	}
	else
	{

		my $op=param('op');
	    my $array = prepare_html();
		if($op)
		{
			my $fname=param('fname');
			my $lname=param('lname');
			my $cidade=param('city');
		    my $sex=param('sex');
		    my $password=param('password');
		    my $email=param('email');
		    my $day=param('day');
		    my $month=param('month');
		    my $year=param('year');
		    my $update=param('updados');
		    my $alert=param('alert');
		    my $dbh=connect_db();
		
		# Tabela Users SQL para referencia
		# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
		#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
			my $query="INSERT INTO Users(F_name,L_name,Email,Bday,Sex,City,Updates,Alert) VALUES(\'".$fname."\',\'".$lname."\',\'".$email."\',\'".$year."-".$month."-".$day."\',";
			if($sex eq "M")
			{
				$query .= "0,\'";
			}
			else
			{
				$query.="1,\'";
			}
			$query.=$cidade."\',";
			if($update eq "update")
			{
				$query.="1,";
			}
			else
			{
				$query.="0,";
			}
			if($alert eq "alert")
			{
				$query.="1";
			}
			else
			{
				$query.="0";
			}
			$query.=");";
			my $sth = $dbh->prepare($query);
			$sth->execute();
					
			# Tabela Autenticacao SQL para referencia
			#  |	0	  |		1   |
			#  | Nro_User | Password|
			$query="INSERT INTO Autenticacao(Password) VALUES(\'".$password."\');";
			my $sth2 = $dbh->prepare($query);
			$sth2->execute();
			$array .= "<h2>Utilizador criado com sucesso, por favor confirme o seu E-mail!</h2><br>";
			$array .= prepare_html2();
			$message.=$email."\nObrigado pelo seu registo!\n\nSe não se registou neste website, por favor ignore este e-mail.";
			$subject="Registo QPO!";
			# enviar email de verificação
			emails($email,$message,$subject);
			return $array;
		}
		else
		{
			template 'register';
		}
	}
};
# activar conta
get '/activate' => sub {
		my $email=param('email');
	    my $dbh=connect_db();
		my $query="UPDATE Users SET Verificado=\'1\' WHERE Email=\'".$email."\';";
		my $sth = $dbh->prepare($query);
		$sth->execute();		
		redirect '/login';
};
# criar nova lista
get '/criarlista' => sub {
	if(session('email') ne "")
	{
		my $op=param('op');
		my $array=prepare_html();
		$array.="<br><a href='/criarlista'><img  src=\"/images/mais.jpeg\"  alt=\"novo\" padding=\"none\" height=\"20\"></a>Criar Lista<br><br><br>";
		if($op)
		{

		# Tabela Lista SQL para referencia
		#  |	0	  |		1  |	2	|	3	| 	4	  |
		#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 

			my $nome=param('nome');
			my $dbh=connect_db();
			my $query="SELECT MAX(Nro_list) FROM Listas;";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			my $ref= $sth->fetchrow_arrayref();
			my $nro=($ref->[0])+1;
			$query="INSERT INTO Listas(Nro_list,Nro_User,Nome) VALUES(".$nro.",".session('Nro_user').",\'".$nome."\');";
			$sth = $dbh->prepare($query);
			$sth->execute();
			$array .= "<h2>Lista criada com sucesso!</h2><br>";
			$message="Foi registado na lista \"".$nome."\" com sucesso, para adicionar pessoas à sua lista clique neste link:\nhttp://localhost:5000/adduser";
			emails(session('email'),$message,$subject);
			# email de criação de lista
		}
		else
		{
			$array.="<form>Nome da Lista:<input type=\"text\" name=\"nome\"><br><input type=\"submit\" name=\"op\" value=Criar></form>";
		}
		$array.=prepare_html2();
		return $array;
	}
	else
	{
		redirect '/login';
	}
};
# activar lista com utilizador
any ['get','post'] => '/activarlista' => sub {
	my $array=prepare_html();
	my $nome=param('nome'); 
	if(session('email') ne "")
	{
		my $email=param('email');
		if(session('email') eq $email)
		{

			my $dbh=connect_db();

			# Tabela Lista SQL para referencia
			#  |	0	  |		1  |	2	|	3	| 	4	  |
			#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
			my $query="SELECT * FROM Listas WHERE Nome=\"".$nome."\";";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			my $ref=$sth->fetchrow_arrayref();
			$query="INSERT INTO Listas(Nro_list,Nro_User,Nome) VALUES(".$ref->[0].",".session('Nro_user').",\'".$nome."\');";
		 	$sth = $dbh->prepare($query);
			$sth->execute();
			$array .= "<h2>Lista subscrita com sucesso! Poderá aceder aos detalhes da mesma no menu das suas listas</h2><br>";

		}
		else
		{
			$array .= "<h2 align=center>Sessão não corresponde ao email de confirmação por favor faça <a align=center href=./logout>Logout</a> e tente novamente.</h2>\n";
		}
	}
	else
	{
		my $op=param('op');
		if($op)
		{
			$array .= "<h2 align=center>Erro credenciais inválidas!!!</h2>\n<br>\n<form align=center method=\"post\">\n<table align=center>\n<tr>\n<td>Email:</td>\n<td>\n<input type=\"text\" name=\"email\" size=\"40\" value=\"\"></td>\n</tr>\n";
			$array .= "<tr>\n<td>Password:</td>\n<td><input type=\"password\" name=\"password\" size=\"32\" value=\"\">\n</td>\n</tr>\n</table>\n";
			$array .= "<input type=hidden name=nome value=".$nome.">\n";
			$array .= "<input type=\"submit\" name=\"op\" value=\"Login\">";
			session "email" => param('email');
		    session "password" => param('password');
			login("/activarlista?email=".session('email')."&nome=".$nome);
		}
		else
		{
			$array .= "<h2 align=center>Por favor faça login para confirmar a subscrição na lista!</h2>\n<br>\n<form align=center method=\"post\">\n<table align=center>\n<tr>\n<td>Email:</td>\n<td>\n<input type=\"text\" name=\"email\" size=\"40\" value=\"\"></td>\n</tr>\n";
			$array .= "<tr>\n<td>Password:</td>\n<td><input type=\"password\" name=\"password\" size=\"32\" value=\"\">\n</td>\n</tr>\n</table>\n";
			$array .= "<input type=hidden name=nome value=".$nome.">\n";
			$array .= "<input type=\"submit\" name=\"op\" value=\"Login\">";
		}
	}
	$array .= prepare_html2();
};
# Aceder a listas
get '/MinhasListas' => sub {
	if(session('email') ne "")
	{
		my $array=prepare_html();
		$array.="<br><a href='/criarlista'><img  src=\"/images/mais.jpeg\"  alt=\"novo\" padding=\"none\" height=\"20\"></a>Criar Lista<br><br>Para consultar as listas clique nos numeros<br>";
		my $dbh=connect_db();

		# Tabela Lista SQL para referencia
		#  |	0	  |		1  |	2	|	3	| 	4	  |
		#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
		my $query="SELECT * FROM Listas WHERE Nro_User=".session('Nro_user').";";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my $i=1;
		while (my $ref = $sth->fetchrow_arrayref())
		{
			my $maior=0;
			my $menor=0;
			if($i==1)
			{
				$array .="<table width=\"75%\">\n<form action=\"/MinhaLista\" method=\"post\">\n<tr>\n<td>Numero</td>\n<td>Nome</td>\n<td>O meu saldo</td>\n<td>Saldo mais Elevado</td>\n<td>Saldo mais Baixo</td></tr>";
			}
			if($ref->[4] eq "0")
			{

				# Tabela Lista SQL para referencia
				#  |	0	  |		1  |	2	|	3	| 	4	  |
				#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
				$query="SELECT * FROM Listas WHERE Nro_list=".$i.";";
				my $sth2 = $dbh->prepare($query);
				$sth2->execute();
				while(my $ref2 = $sth2->fetchrow_arrayref())
				{
					if($ref2->[2]>$maior)
					{
						$maior=$ref2->[2]/100;
					}
					if($ref2->[2]<$menor)
					{
						$menor=$ref2->[2]/100;
					}
				}
				my $meu=($ref->[2]/100);
				$array .="<tr>\n<td><input type=submit name=Ver value=".$i.">\n</td>\n<td>".$ref->[3]."</td>\n<td>";
				if($meu<0)
				{
					$array.="<font color=red>".$meu." €</font></td>\n<td>";
				}
				else
				{
					$array.=$meu." €</td>\n<td>";
				}
				if($maior<0)
				{
					$array.="<font color=red>".$maior." €</font></td>\n<td>";
				}
				else
				{
					$array.=$maior." €</td>\n<td>";
				}
				if($menor<0)
				{
					$array.="<font color=red>".$menor." €</font></td>\n</tr>";
				}
				else
				{
					$array.=$menor." €</td>\n</tr>";
				}
			}
			$i++;
		}
		if($i==1)
		{
			$array.="<b>Nenhuma lista criada/aderida</b>";
		}
		else
		{
			$array.="\n</form>\n</table>";
		}
		$array .= prepare_html2();
		return $array;
	}
	else
	{

		redirect 'login';
	}
};
# Lista compras da lista selecionada
any ['get','post'] => '/MinhaLista' => sub {
	if(session('email') ne "")
	{
		my $array=prepare_html();
		$array.="<br><form action='/criarsubmissao'><input type=image src=\"/images/mais.jpeg\"  alt=\"novo\" padding=\"none\" height=\"20\" name=sub value=".param('Ver').">Nova Submissão</form><br>";
		my $dbh=connect_db();


		# Tabela Submissao SQL para referencia
		#  |	0	  |		1  |	 2 	  |	  3  | 	 4	     |		5 	|    6     |  7    |
		#  | Sub_id | Nro_User | Nro_list | Data | Descrição | Pagantes |Eliminada | Valor |
		my $query="SELECT * FROM Submissao WHERE Nro_list=".param('Ver')." ORDER BY Data DESC;";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my $i=1;
		while (my $ref = $sth->fetchrow_arrayref())
		{
			if($i==1)
			{

				$array.="<table>";


				# Tabela Lista SQL para referencia
				#  |	0	  |		1  |	2	|	3	| 	4	  |
				#  | Nro_List | Nro_User | Saldo | Nome | Fechada | 
				$query="SELECT * FROM Listas WHERE Nro_list=".param('Ver').";";
				my $sth3 = $dbh->prepare($query);
				$sth3->execute();
				# listar saldo individual
				while(my $ref3 = $sth3->fetchrow_arrayref())
				{
				
					# Tabela Users SQL para referencia
					# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
					#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
		
					$query="SELECT * FROM Users WHERE Nro_User=".$ref3->[1].";";
					my $sth4 = $dbh->prepare($query);
					$sth4->execute();
					my $ref4 = $sth4->fetchrow_arrayref();
					$array .="<td>\n<table><tr><td>".$ref4->[1]." ".$ref4->[2]."</td></tr>\n";
					my $novo=$ref3->[2]/100;
					if($novo<0)
					{
						$array .="\n<tr><td><font color=red>".$novo." €</font></td></tr></table></td>\n";
					}
					else
					{
						$array .="\n<tr><td>".$novo." €</td></tr></table></td>\n";
					}
				}

				$array.="</table><br>";
				$array .="<table width=\"75%\">\n<form action=\"/eliminar_sub\" method=\"post\">\n<tr>\n<td>Quem Pagou:</td>\n<td>Data</td>\n<td>Valor</td>\n<td>Descrição</td>\n<td>Pagantes</td>\n<td>Eliminada</td></tr>";
			}
			my @persons= split(',',$ref->[5]);
			my $valor=($ref->[7])/100;
			
			# Tabela Users SQL para referencia
			# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
			#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
		
			$query="SELECT * FROM Users WHERE Nro_User=".$ref->[1].";";
			my $sth2 = $dbh->prepare($query);
			$sth2->execute();
			my $ref2 = $sth2->fetchrow_arrayref();
			if($ref->[6] eq "1")
			{
				$array.="<tr class=strikeout>\n<td>".$ref2->[1]." ".$ref2->[2]."</td>\n<td>".$ref->[3]."</td>\n<td>".$valor." €</td>\n<td>".$ref->[4]."</td>\n<td>";
				$array.=stringarPagantes(@persons);
				$array.="</td>\n<td><input type=image src=/images/delete.png onclick=\"return false;\" alt=\"novo\" padding=\"none\" height=\"20\" name=eliminar value=x></td>\n</tr>";
			}
			else
			{
				$array.="<tr>\n<td>".$ref2->[1]." ".$ref2->[2]."</td>\n<td>".$ref->[3]."</td>\n<td>".$valor." €</td>\n<td>".$ref->[4]."</td>\n<td>";
				$array.=stringarPagantes(@persons);
				$array.="</td>\n<td><input type=image src=/images/delete.png  alt=\"novo\" padding=\"none\" height=\"20\" name=eliminar value=".$ref->[0]."></td>\n</tr>";			
			}	
			$i++;
		}
		if($i==1)
		{
			$array.="<b>Nenhuma submissão criada nesta lista</b><br>";
		}
		else
		{
			$array.="\n</form>\n</table>";
		}
		$array .= "<br><form action='/adduser'><input type=image src=\"/images/mais.jpeg\"  alt=\"novo\" padding=\"none\" height=\"20\" name=sub value=".param('Ver').">Adicionar novo utilizador a lista<input type=hidden name=lista value=".param('Ver')."></form><br><br><form action='/acerto'><input type=hidden name=lista value=".param('Ver')."><input type=submit onclick='return conf();' name=\"del\" value=\"Acertar Contas da Lista\"></form>".prepare_html2();
		return $array;
	}
	else
	{

		redirect 'login';
	}
};
# eliminar compra

post '/eliminar_sub' => sub {
	my $array=prepare_html();
	my $dbh=connect_db();
	if(param('eliminar'))
	{
		$array.="<b>Submissão eliminada com sucesso!</b><br><input type=image src=\"/images/mais.jpeg\"  alt=\"novo\" padding=\"none\" height=\"20\" name=sub value=".param('Ver').">Nova Submissão<br><br><br>";
		

		# Tabela Submissao SQL para referencia
		#  |	0	  |		1  |	 2 	  |	  3  | 	 4	     |		5 	|    6     |  7    |
		#  | Sub_id | Nro_User | Nro_list | Data | Descrição | Pagantes |Eliminada | Valor |
		my $query="SELECT * FROM Submissao where Sub_id=".param('eliminar').";";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my $ref = $sth->fetchrow_arrayref();
		my @mult=split(',',$ref->[5]);
		my $div=0;
		foreach my $val (@mult) 
		{
			my @multi=split('x',$val);
			$div=$div+$multi[0];
		}
		foreach my $val (@mult) 
		{
			my @multi=split('x',$val);
			my $novosaldo=($multi[0]*$ref->[7])/$div;

			# Tabela Lista SQL para referencia
			#  |	0	  |		1  |	2	|	3	| 	4	  |
			#  | Nro_List | Nro_User | Saldo | Nome | Fechada |
			$query="SELECT * FROM Listas Where Nro_list=".$ref->[2]." AND Nro_User=".$multi[1].";";
			my $sth2 = $dbh->prepare($query);
			$sth2->execute();
			my $ref2=$sth2->fetchrow_arrayref();
			my $valor;
			if($ref->[1]==$multi[1])
			{
				$valor=$ref2->[2]-($ref->[7]-$novosaldo);
			}
			else
			{
				$valor=($ref2->[2]+$novosaldo);
			}
			$query="UPDATE Listas SET Saldo=".$valor." Where Nro_list=".$ref->[2]." AND Nro_User=".$multi[1].";";
			my $sth3 = $dbh->prepare($query);
			$sth3->execute();
			$query="UPDATE Submissao SET Eliminada=1 Where Sub_id=".param('eliminar').";";
			my $sth4 = $dbh->prepare($query);
			$sth4->execute();
		}
	}
	$array.=prepare_html2();
	return $array;
};
# adiciona user a lista
any ['get','post'] => '/adduser' => sub {
	my $op=param('op');
	my $array=prepare_html();
	if($op)
	{
		my $email=param('email');
		my $dbh=connect_db();

		# Tabela Lista SQL para referencia
		#  |	0	  |		1  |	2	|	3	| 	4	  |
		#  | Nro_List | Nro_User | Saldo | Nome | Fechada |
		my $query="SELECT * FROM Listas WHERE Nro_list=".param('lista').";";
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my $ref= $sth->fetchrow_arrayref();
		my @nome=split(' ',$ref->[3]);
		print $nome[0]." ".$nome[1]." ".$nome[2]."\n\n\n";
		$message="Foi registado na lista \"".$ref->[3]."\" por ".session('Fnome')." ".session('Lnome').", para confirmar clique neste link:\nhttp://localhost:5000/activarlista?email=".$email."&nome=";
		my $n = $#nome;
		foreach my $val (@nome) 
		{
			if($n--)
			{
				$message.=$val."%20";
			}
			else
			{
				$message.=$val."\n";
			}
		}
		$message.="\n\nSe não pretender participar nesta lista por favor ignore este e-mail.";
		if(param('desc'))
		{
			$message.="\nA mensagem de ".session('Fnome')." ".session('Lnome')." foi:\n\"".param('desc')."\"";
		}
		$subject="Convite para Lista QPO!";
		# envia email com convite para aceitação
		emails($email,$message,$subject);
		$array.=prepare_html2();
		return $array;
	}
	else
	{
		$array .= "Convida um amigo para participar na tua lista<br><br><form action='/adduser'>Email:<input type=email name=email><br>Adiciona uma mensagem:<br><textarea cols=80 rows=4 name=\"desc\" value=\"\" placeholder='(opcional)'></textarea>";
		$array .= "<input type=hidden name=lista value=".param('lista')."><input type=\"submit\" name=\"op\" value=\"Convidar\"></form>";
	}
	
};
# acerto de contas
any ['get','post'] => '/acerto' => sub {
	if(session('email') eq "")
	{
		redirect '/MinhasListas';
	}	
	else
	{
		my $op=param('del');
	    my $array = prepare_html();
		if($op)
		{
			my $dbh=connect_db();
			# poe os saldos a 0
			my $query="UPDATE Listas SET Saldo=0, Fechada=1 WHERE Nro_list=".param('lista').";";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			# marca as submissoes como eliminadas
			$query="UPDATE Submissao SET Eliminada=1 WHERE Nro_list=".param('lista').";";
			my $sth2 = $dbh->prepare($query);
			$sth2->execute();
			
			$query="SELECT * FROM Listas WHERE Nro_list=".param('lista').";";
			my $sth3 = $dbh->prepare($query);
			$sth3->execute();
			while(my $ref = $sth3->fetchrow_arrayref())
			{
				$query="SELECT * FROM Users WHERE Nro_User=".$ref->[1].";";
				my $sth4 = $dbh->prepare($query);
				$sth4->execute();
				my $ref2 = $sth4->fetchrow_arrayref();
				$message="Foram acertadas as contas na sua lista - \"".$ref->[3]."\" por " .session('Fnome')." ".session('Lnome').". Consequentemente todos os saldos foram repostos a 0 €.\n Podera ver as mudanças aqui:\nhttp://localhost:5000/MinhasListas";
				$subject="Acerto de contas QPO";
				emails($ref2->[3],$message,$subject);
				#envia email a todos os utilizadores da lista com o acerto das contas

			}
			$array .= "Acerto efectuado com sucesso um e-mail foi enviado a todos os Utilizadores desta lista\n<br>".prepare_html2();
			return $array;
		}
		else
		{	
			redirect 'login';
		}
	}
};
# criar nova compra
any ['get','post'] => '/criarsubmissao' => sub {
	if(session('email') eq "")
	{
		redirect '/MinhasListas';
	}
	else
	{
		my $op=param('op');
		my $nro=param('sub');
		my $array=prepare_html();
		my $dbh=connect_db();	
		if($op)
		{
			my $data=param('data');
			my $valor=param('amount');
			my $des=param('desc');
			my $nrouser=param('nro');
			my $pagantes;
			for(my $i=1;$i<=$nrouser;$i++)
			{
				my $paga=param('mult'.$i);
				
				# Tabela Users SQL para referencia
				# 	|	0	  |		1  |	2	|	3	| 	4  |  5  |  6 | 	7	|	8	|	9		 |		10	 |
				#  | Nro_User | F_name | L_name | Email | Bday | Sex | SU | Updates | Alert | Verificado | Existente |
		
				my $query="SELECT * FROM Users WHERE Email=\'".param('email'.$i)."\';";
				my $sth = $dbh->prepare($query);
				$sth->execute();
				my $ref = $sth->fetchrow_arrayref();
				$pagantes.=$paga."x".$ref->[0];
				if($ref->[8] == 1)
				{
					$message="Foi submetido uma nova compra na sua lista de valor " .$valor."€ consequentemente o seu saldo foi alterado.\n Podera ver as mudanças aqui:\nhttp://localhost:5000/MinhasListas";
					$subject="Update do seu saldo QPO";
					emails($ref->[3],$message,$subject);
					# email para quem tem os alertas activos
				}
				if($i<$nrouser)
				{
					$pagantes.=",";
				}
			}
			my $query="INSERT INTO Submissao(Nro_User,Nro_list,Data,Descricao,Pagantes,Valor) VALUES(".session('Nro_user').",".$nro.",\'".$data."\',\'".$des."\',\'".$pagantes."\',".($valor*100).");";
			my $sth2 = $dbh->prepare($query);
			print $query."\n\n\n";
			$sth2->execute();
			insersaolist($nro,$pagantes,$valor);
			$array .= "<embed src=\"s.wav\" autostart=false loop=\"infinite\" hidden=true><h2>Submissao feita com sucesso! Poderá alter aos detalhes da mesma no menu das suas lista</h2><br>";
		}
		else
		{
			$array .="<form align=center onSubmit=\"return ValidateValor();\" method=\"post\">\nDescrição:<br><textarea name=\"desc\" cols=60 value=\"\"></textarea>\n<br>";
			my $dbh=connect_db();
			my $query="SELECT * FROM Listas WHERE Nro_list=\'".$nro."\';";
			my $sth = $dbh->prepare($query);
			$sth->execute();
			my $i=1;
			my $datestring = strftime "%F", localtime;
			$array.="Data:<input type=date name=data value=".$datestring.">      Valor:<input type=text id=valor placeholder=\"0.00\" name=amount><br>Quem participou?<br><br>";
			while (my $ref = $sth->fetchrow_arrayref())
			{
				my $query="SELECT * FROM Users WHERE Nro_User=\'".$ref->[1]."\';";
				my $sth2 = $dbh->prepare($query);
				$sth2->execute();
				my $ref2=$sth2->fetchrow_arrayref();
				$array .="<input type=hidden name=email".$i." value=".$ref2->[3]."><div id=data".$i.">".$ref2->[1]." ".$ref2->[2]." x<script>data(2,".$i.");</script></div>";
				$i++;
			}
			$array .= "<input type=hidden name=sub value=".$nro."><input type=hidden name=nro value=".($i-1)."><input type=\"submit\" name=\"op\" value=\"Inserir\">";
		}
		$array.=prepare_html2();
		return $array;
	}	
};
# pagina de login
any ['get','post'] => '/login' => sub {
	if(session('email') ne "")
	{
		redirect '/MinhasListas';
	}	
	else
	{
		my $op=param('op');
	    my $array = prepare_html();
	    	$array .= "<h2 align=center>Erro credenciais inválidas!!!</h2>\n<br>\n<form align=center method=\"post\">\n<table align=center>\n<tr>\n<td>Email:</td>\n<td>\n<input type=\"text\" name=\"email\" size=\"40\" value=\"\"></td>\n</tr>\n";
			$array .= "<tr>\n<td>Password:</td>\n<td><input type=\"password\" name=\"password\" size=\"32\" value=\"\">\n</td>\n</tr>\n</table>\n";
			$array .= "<input type=\"submit\" name=\"op\" onclick=\"play()\" value=\"Login\">\n<audio id=\"audio\" src=\"t.mp3\" ></audio>";
		if($op)
		{	
		    session "email" => param('email');
		    session "password" => param('password');
			login("/MinhasListas");
			$array .= prepare_html2();
			return $array;
		}
		else
		{	
			template 'login';
		}
	}
};
true;
