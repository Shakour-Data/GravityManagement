'use client'

import React, { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Alert } from '@/components/ui/alert'
import { Loader2, Edit, Trash2, ArrowLeft, Play, GitBranch, AlertTriangle, Calendar, TrendingUp } from 'lucide-react'
import { useRule, useDeleteRule, useTestRule } from '@/lib/hooks'

interface Rule {
  id: string
  name: string
  description: string
  type: 'validation' | 'automation' | 'notification'
  conditions: any[]
  actions: any[]
  priority: 'low' | 'medium' | 'high'
  active: boolean
  created_at: string
  updated_at: string
  test_results?: any[]
  execution_history?: any[]
}

export default function RuleDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  const { data: rule, loading, error } = useRule(id)
  const deleteRule = useDeleteRule()
  const testRule = useTestRule(id)

  const [showTestModal, setShowTestModal] = useState(false)

  const handleDelete = async () => {
    if (window.confirm(t('confirmDeleteRule', 'Are you sure you want to delete this rule?'))) {
      try {
        await deleteRule.mutate(id)
        router.push('/rules')
      } catch (error) {
        console.error('Failed to delete rule:', error)
      }
    }
  }

  const handleTestRule = async () => {
    setShowTestModal(true)
    try {
      await testRule.mutate(id)
    } catch (error) {
      console.error('Failed to test rule:', error)
    }
  }

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (error || !rule) {
    return (
      <div className="p-6">
        <Alert variant="destructive">
          {t('failedToLoadRule', 'Failed to load rule')}: {error}
        </Alert>
        <Button onClick={() => router.back()} className="mt-4">
          <ArrowLeft className="h-4 w-4 mr-2" />
          {t('back', 'Back')}
        </Button>
      </div>
    )
  }

  const typedRule = rule as Rule

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-4">
          <Button onClick={() => router.back()} variant="outline">
            <ArrowLeft className="h-4 w-4 mr-2" />
            {t('back', 'Back')}
          </Button>
          <h1 className="text-3xl font-bold">{typedRule.name}</h1>
        </div>
        <div className="flex space-x-2">
          <Button variant="outline" onClick={handleTestRule}>
            <Play className="h-4 w-4 mr-2" />
            {t('testRule', 'Test Rule')}
          </Button>
          <Link href={`/rules/${id}/edit`}>
            <Button variant="outline">
              <Edit className="h-4 w-4 mr-2" />
              {t('edit', 'Edit')}
            </Button>
          </Link>
          <Button variant="destructive" onClick={handleDelete}>
            <Trash2 className="h-4 w-4 mr-2" />
            {t('delete', 'Delete')}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        {/* Rule Overview */}
        <Card className="p-6 lg:col-span-2">
          <h2 className="text-xl font-semibold mb-4">{t('ruleOverview', 'Rule Overview')}</h2>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium text-gray-600">{t('description', 'Description')}</label>
              <p className="mt-1">{typedRule.description}</p>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('type', 'Type')}</label>
                <div className="mt-1">
                  <Badge variant={
                    typedRule.type === 'validation' ? 'default' :
                    typedRule.type === 'automation' ? 'secondary' :
                    'outline'
                  }>
                    <GitBranch className="h-3 w-3 mr-1" />
                    {typedRule.type}
                  </Badge>
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('priority', 'Priority')}</label>
                <div className="mt-1">
                  <Badge variant={
                    typedRule.priority === 'high' ? 'destructive' :
                    typedRule.priority === 'medium' ? 'default' :
                    'secondary'
                  }>
                    {typedRule.priority}
                  </Badge>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('status', 'Status')}</label>
                <div className="mt-1">
                  <Badge variant={typedRule.active ? 'default' : 'secondary'}>
                    {typedRule.active ? t('active', 'Active') : t('inactive', 'Inactive')}
                  </Badge>
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('lastUpdated', 'Last Updated')}</label>
                <p className="mt-1 text-sm">{new Date(typedRule.updated_at).toLocaleDateString()}</p>
              </div>
            </div>
          </div>
        </Card>

        {/* Quick Stats */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('quickStats', 'Quick Stats')}</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <TrendingUp className="h-5 w-5 text-green-500" />
                <span className="text-sm">{t('executions', 'Executions')}</span>
              </div>
              <span className="font-semibold">{typedRule.execution_history?.length || 0}</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Calendar className="h-5 w-5 text-blue-500" />
                <span className="text-sm">{t('created', 'Created')}</span>
              </div>
              <span className="font-semibold text-sm">{new Date(typedRule.created_at).toLocaleDateString()}</span>
            </div>
          </div>
        </Card>
      </div>

      {/* Conditions and Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('conditions', 'Conditions')}</h2>
          {typedRule.conditions && typedRule.conditions.length > 0 ? (
            <div className="space-y-3">
              {typedRule.conditions.map((condition: any, index: number) => (
                <div key={index} className="border rounded-lg p-3">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="font-medium">{condition.field}</h3>
                      <p className="text-sm text-gray-600">
                        {condition.operator} {condition.value}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">
              {t('noConditions', 'No conditions defined')}
            </div>
          )}
        </Card>

        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('actions', 'Actions')}</h2>
          {typedRule.actions && typedRule.actions.length > 0 ? (
            <div className="space-y-3">
              {typedRule.actions.map((action: any, index: number) => (
                <div key={index} className="border rounded-lg p-3">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="font-medium">{action.type}</h3>
                      <p className="text-sm text-gray-600">
                        {action.field}: {action.value}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">
              {t('noActions', 'No actions defined')}
            </div>
          )}
        </Card>
      </div>

      {/* Execution History */}
      <Card className="p-6">
        <h2 className="text-xl font-semibold mb-4">{t('executionHistory', 'Execution History')}</h2>
        {typedRule.execution_history && typedRule.execution_history.length > 0 ? (
          <div className="space-y-4">
            {typedRule.execution_history.map((execution: any, index: number) => (
              <div key={index} className="border rounded-lg p-4">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="font-medium">{execution.trigger}</h3>
                    <p className="text-sm text-gray-600">
                      {t('executedAt', 'Executed at')}: {new Date(execution.executed_at).toLocaleString()}
                    </p>
                    <p className="text-sm text-gray-600">
                      {t('result', 'Result')}: {execution.result}
                    </p>
                  </div>
                  <Badge variant={execution.success ? 'default' : 'destructive'}>
                    {execution.success ? t('success', 'Success') : t('failed', 'Failed')}
                  </Badge>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            {t('noExecutionHistory', 'No execution history available')}
          </div>
        )}
      </Card>

      {/* Test Rule Modal */}
      {showTestModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <Card className="p-6 max-w-md w-full mx-4">
            <h2 className="text-xl font-semibold mb-4">{t('testRule', 'Test Rule')}</h2>
            {testRule.loading ? (
              <div className="flex items-center justify-center py-4">
                <Loader2 className="h-6 w-6 animate-spin mr-2" />
                {t('testingRule', 'Testing rule...')}
              </div>
            ) : testRule.data ? (
              <div>
                <h4 className="font-medium mb-2">{t('testResults', 'Test Results')}</h4>
                <pre className="bg-gray-100 p-4 rounded text-sm overflow-x-auto">
                  {JSON.stringify(testRule.data, null, 2)}
                </pre>
              </div>
            ) : testRule.error ? (
              <Alert variant="destructive">
                <AlertTriangle className="h-4 w-4" />
                {t('testFailed', 'Test failed')}: {testRule.error}
              </Alert>
            ) : null}
            <div className="flex justify-end mt-4">
              <Button onClick={() => setShowTestModal(false)}>
                {t('close', 'Close')}
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  )
}
