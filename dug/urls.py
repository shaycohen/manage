from django.conf.urls import patterns, url
from dug import views

urlpatterns = patterns('',
    url(r'^jobs/(?P<client>\d+)/?$', views.jobs, name='jobs'),
    url(r'^jobs/(?P<client>\d+)/latest$', views.latest, name='latest'),


)

