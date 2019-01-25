cd ~/Documents/ideaspace/openSource/xxl-job
git checkout jc/local_server_for_v1.9.1
cd xxl-job-admin
echo 'xxl-job-admin-1.9.1 start,admin/123456,http://localhost:18080/xxl-job-admin/'
mvn tomcat7:run