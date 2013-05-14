from django.conf.urls import patterns, include, url
from dug.views import JobUpdate

# Uncomment the next two lines to enable the admin:
# from django.contrib import admin
# admin.autodiscover()

urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'manage.views.home', name='home'),
    url(r'^dug/', include('dug.urls')),
    url(r'^meta/', 'manage.views.meta', name='meta'),
    url(r'^(?P<pk>\d+)', JobUpdate.as_view(), name='jobupdate'),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    # url(r'^admin/', include(admin.site.urls)),
)
