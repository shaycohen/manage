from django.http import HttpResponse
from dug.models import Job
from dug.models import Client
import time
import yaml

def jobs(request, client):
	jobArr=Job.objects.filter(client=client)
	response = {}
	for job in jobArr:
		response[job.id] = job.__dict__
		response[job.id]['exec'] = job.execText()
		response[job.id]['class'] = job._meta.object_name
		response[job.id]['responseGetDate'] = time.mktime(time.gmtime())
	return HttpResponse(yaml.dump(response, default_flow_style=False, allow_unicode=True, explicit_start=True, canonical=False), content_type='text/plain')

def latest(request, client):
	latest = time.mktime(Client.objects.get(pk=client).jobs.latest().timestamp.timetuple())
	return HttpResponse(yaml.dump(latest, default_flow_style=False, allow_unicode=True))

