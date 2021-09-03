Pré Requisitos:

Gerar o dump com EXP, e não EXPDP

Passos para importar:

1) Criar uma Ec2, t2.micro com a AMI: OL7.2-x86_64-HVM-2015-12-10 (ami-b24acede)

2) Habilitar swap na máquina

sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
sudo /sbin/mkswap /var/swap.1
sudo /sbin/swapon /var/swap.1

/etc/fstab:
/var/swap.1 swap swap defaults 0 0

3) Baixar client Oracle 12c:
http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html

4) Instalar Oracle Client Admin seguindo os passos:

User root:
yum  -y install oracle-rdbms-server-12cR1-preinstall
unzip linuxamd64_12c_client.zip
mkdir  -p /u01/app/12.1.0.2
chown oracle:dba /u01/app
chown oracle:dba /u01/app/12.1.0.2
mkdir /u01/app/base
chown oracle:dba /u01/app/base
mkdir /u01/app/12.1.0.2/admclient64
User Oracle:
set -x
cd client
DISTRIB=`pwd`
./runInstaller -silent \
 -responseFile $DISTRIB//response/client_install.rsp   \
   oracle.install.client.installType=Administrator     \
   UNIX_GROUP_NAME=dba                                 \
   INVENTORY_LOCATION=/u01/app/oraInventory            \
   SELECTED_LANGUAGES=en                               \
   ORACLE_HOME=/u01/app/12.1.0.2/admclient64           \
   ORACLE_BASE=/u01/app/base                           \
   waitForCompletion=true

Colocar no bash_profile do usuário Oracle:
export ORACLE_HOME=/u01/app/12.1.0.2/admclient64
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
PATH=$ORACLE_HOME/bin:$PATH
Criar entrada no tnsnames.ora
$ORACLE_HOME/network/admin/tnsnames.ora
Testar a conexão
sqlplus user/passwd@

5) importar o dump
Transferir o dump para a EC2 e importar utilizando o comando abaixo
imp userID/password@$service FROMUSER=cust_schema TOUSER=cust_schema FILE=exp_file.dmp LOG=imp_file.log
Fonte:
https://pierreforstmanndotcom.wordpress.com/2015/06/29/oracle-client-12-1-0-2-silent-installations-on-oracle-linux/
https://d0.awsstatic.com/whitepapers/strategies-for-migrating-oracle-database-to-aws.pdf​



# RDS instance info
my $RDS_PORT=1521;
my $RDS_HOST="teste.cpuk3vetnlol.sa-east-1.rds.amazonaws.com";
my $RDS_LOGIN="";
my $RDS_SID="ORCL";

#The $ARGV[0] is a parameter you pass into the script
my $dirname = "DATA_PUMP_DIR";
my $fname = $ARGV[0];

my $data = "dummy";
my $chunk = 8192;

my $sql_open = "BEGIN perl_global.fh := utl_file.fopen(:dirname, :fname, 'wb', :chunk); END;";
my $sql_write = "BEGIN utl_file.put_raw(perl_global.fh, :data, true); END;";
my $sql_close = "BEGIN utl_file.fclose(perl_global.fh); END;";
my $sql_global = "create or replace package perl_global as fh utl_file.file_type; end;";

my $conn = DBI->connect('dbi:Oracle:host='.$RDS_HOST.';sid='.$RDS_SID.';port='.$RDS_PORT,$RDS_LOGIN, '') || die ( $DBI::errstr . "\n");

my $updated=$conn->do($sql_global);
my $stmt = $conn->prepare ($sql_open);
$stmt->bind_param_inout(":dirname", \$dirname, 12);
$stmt->bind_param_inout(":fname", \$fname, 12);
$stmt->bind_param_inout(":chunk", \$chunk, 4);
$stmt->execute() || die ( $DBI::errstr . "\n");

open (INF, $fname) || die "\nCan't open $fname for reading: $!\n";
binmode(INF);
$stmt = $conn->prepare ($sql_write);
my %attrib = ('ora_type','24');
my $val=1;
while ($val> 0) {
  $val = read (INF, $data, $chunk);
  $stmt->bind_param(":data", $data , \%attrib);
  $stmt->execute() || die ( $DBI::errstr . "\n") ; };
die "Problem copying: $!\n" if $!;
close INF || die "Can't close $fname: $!\n";
  $stmt = $conn->prepare ($sql_close);
$stmt->execute() || die ( $DBI::errstr . "\n") ;




wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

- isntall CPAN - 

yum install perl-CPAN.noarch

- isntall DBI - 

Switch to root: su -
Run CPAN: perl -MCPAN -e shell
Check if DBI is already installed: m DBI
If it’s not installed, install it: install DBI

- DBD::Oracle - 

wget http://search.cpan.org/CPAN/authors/id/P/PY/PYTHIAN/DBD-Oracle-1.64.tar.gz

yum install perl-ExtUtils-MakeMaker -y

$ tar xzf DBD-Oracle-1.74.tar.gz $
$ cd DBD-Oracle-1.74
$ mkdir $ORACLE_HOME/log
$ perl Makefile.PL
$ make
$ make install


- - -  acompanhar a transferencia - - - 
alter session set nls_date_format = 'dd/mm/yyyy hh24:mi:ss';
 select filename, type, filesize/1024/1024 as MB, sysdate from table(RDSADMIN.RDS_FILE_UTIL.LISTDIR('DATA_PUMP_DIR'))


