from django.db import models
from django.db.models.query import QuerySet
from django.contrib.contenttypes.models import ContentType
from django.core.urlresolvers import reverse, reverse_lazy
import sys

# Implementation of http://djangosnippets.org/snippets/1034/
class JobQuerySet(QuerySet):
    def __getitem__(self, k):
        result = super(JobQuerySet, self).__getitem__(k)
        if isinstance(result, models.Model) :
            return result.as_leaf_class()
        else :
            return result
    def __iter__(self):
        for item in super(JobQuerySet, self).__iter__():
            yield item.as_leaf_class()

class JobManager(models.Manager):
    def get_query_set(self):
        return JobQuerySet(self.model)

class Job(models.Model):
   objects = JobManager()
   def __unicode__(self):
    return self.desc
   def save(self, *args, **kwargs):
       if(not self.content_type):
           self.content_type = ContentType.objects.get_for_model(self.__class__)
           super(Job, self).save(*args, **kwargs)
   def as_leaf_class(self):
       content_type = self.content_type
       model = content_type.model_class()
       if (model == Job):
           return self
       return model.objects.get(id=self.id)
   def get_absolute_url(self):
       #return reverse('main/jobupdate/' + str(self.pk))
        return reverse(str(self.pk))

   content_type = models.ForeignKey(ContentType,editable=False,null=True)
   desc = models.CharField(max_length=1024)
   STATUSC = ( ('new','New'), ('disp','Dispatched'), ('done', 'Done'), ('err', 'Error') )
   status = models.CharField(choices=STATUSC,default='new',max_length=10)
   output = models.TextField()
#   class Meta: 
#    abstract = True

class ShellJob(Job):
   objects = JobManager()
   def __unicode__(self):
    return self.desc
   shell = models.CharField(max_length=104,default='/bin/sh')
   command = models.CharField(max_length=1024)
   args = models.CharField(max_length=2048)

class PuppetJob(Job):
   objects = JobManager()
   def __unicode__(self):
    return self.desc
   module = models.CharField(max_length=1024)
   data = models.CharField(max_length=4096)

class Client(models.Model):
   def __unicode__(self):
    return self.hwaddr
   jobs = models.ManyToManyField(Job)
   hwaddr = models.CharField(max_length=18)
   name = models.CharField(max_length=64)
