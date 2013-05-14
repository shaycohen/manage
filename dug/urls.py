from django.conf.urls import patterns, url
from dug import views

urlpatterns = patterns('',
    url(r'^(?P<client>\d+)/?$', views.jobs, name='jobs'),
    url(r'^listclientjobs/?$', views.listClientJobs, name='listclientjobs'),
    url(r'^jobcreate$', views.JobCreate.as_view(), name='jobcreate'),
    url(r'^jobupdate/(?P<pk>\d+)$', views.JobUpdate.as_view(), name='jobupdate'),
    url(r'^jobdelete$', views.JobDelete.as_view(), name='jobdelete'),


)

