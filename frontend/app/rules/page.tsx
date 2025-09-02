'use client'

import React, { useState } from 'react'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { Table } from '@/components/ui/table'
import { Modal, ModalPortal, ModalOverlay, ModalContent, ModalHeader, ModalTitle, ModalFooter } from '@/components/ui/modal'
import { Alert } from '@/components/ui/alert'
import { Loader2, Plus, Edit, Trash2, Play, GitBranch, AlertTriangle } from 'lucide-react'
import { useRules, useCreateRule, useUpdateRule, useDeleteRule, useTestRule } from '@/lib/hooks'

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
}

export default function RulesPage() {
  const { t } = useTranslation('common')
  const { data: rules, loading, error } = useRules()
  const createRule = useCreateRule()
  const updateRule = useUpdateRule('')
  const deleteRule = useDeleteRule()
  const testRule = useTestRule('')

  const [filterType, setFilterType] = useState<string>('all')
  const [searchTerm, setSearchTerm] = useState('')
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [editingRule, setEditingRule] = useState<Rule | null>(null)
  const [showTestModal, setShowTestModal] = useState(false)
  const [testRuleId, setTestRuleId] = useState<string>('')

  const [formData, setFormData] = useState({
    name: '',
    description: '',
    type: 'validation' as 'validation' | 'automation' | 'notification',
    conditions: '',
    actions: '',
    priority: 'medium' as 'low' | 'medium' | 'high',
    active: true
  })

  const filteredRules = (rules as Rule[])?.filter((rule: Rule) => {
    const matchesType = filterType === 'all' || rule.type === filterType
    const matchesSearch = rule.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         rule.description.toLowerCase().includes(searchTerm.toLowerCase())
    return matchesType && matchesSearch
  }) || []

  const handleCreateRule = async () => {
    try {
      await createRule.mutate({
        ...formData,
        conditions: JSON.parse(formData.conditions || '[]'),
        actions: JSON.parse(formData.actions || '[]')
      })
      setShowCreateForm(false)
      resetForm()
    } catch (error) {
      console.error('Failed to create rule:', error)
    }
  }

  const handleUpdateRule = async () => {
    if (!editingRule) return
    try {
      await updateRule.mutate({
        ...formData,
        conditions: JSON.parse(formData.conditions || '[]'),
        actions: JSON.parse(formData.actions || '[]')
      })
      setEditingRule(null)
      resetForm()
    } catch (error) {
      console.error('Failed to update rule:', error)
    }
  }

  const handleDeleteRule = async (id: string) => {
    if (confirm(t('confirmDeleteRule', 'Are you sure you want to delete this rule?'))) {
      try {
        await deleteRule.mutate(id)
      } catch (error) {
        console.error('Failed to delete rule:', error)
      }
    }
  }

  const handleTestRule = async (id: string) => {
    setTestRuleId(id)
    setShowTestModal(true)
    try {
      await testRule.mutate(id)
    } catch (error) {
      console.error('Failed to test rule:', error)
    }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      description: '',
      type: 'validation',
      conditions: '',
      actions: '',
      priority: 'medium',
      active: true
    })
  }

  const openEditModal = (rule: Rule) => {
    setEditingRule(rule)
    setFormData({
      name: rule.name,
      description: rule.description,
      type: rule.type,
      conditions: JSON.stringify(rule.conditions, null, 2),
      actions: JSON.stringify(rule.actions, null, 2),
      priority: rule.priority,
      active: rule.active
    })
  }

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (error) {
    return (
      <div className="text-center py-8 text-red-500">
        {t('failedToLoadRules', 'Failed to load rules')}: {error}
      </div>
    )
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">{t('rules', 'Rules')}</h1>
        <Button onClick={() => setShowCreateForm(true)}>
          <Plus className="h-4 w-4 mr-2" />
          {t('createRule', 'Create Rule')}
        </Button>
      </div>

      {/* Filters */}
      <Card className="p-4 mb-6">
        <div className="flex gap-4">
          <Input
            placeholder={t('searchRules', 'Search rules...')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1"
          />
          <Select value={filterType} onValueChange={setFilterType}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder={t('filterByType', 'Filter by type')} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">{t('allTypes', 'All Types')}</SelectItem>
              <SelectItem value="validation">{t('validation', 'Validation')}</SelectItem>
              <SelectItem value="automation">{t('automation', 'Automation')}</SelectItem>
              <SelectItem value="notification">{t('notification', 'Notification')}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </Card>

      {/* Rules Table */}
      <Card className="p-4">
        <h3 className="text-lg font-semibold mb-4">{t('rulesList', 'Rules List')}</h3>
        <Table>
          <thead>
            <tr>
              <th>{t('name', 'Name')}</th>
              <th>{t('type', 'Type')}</th>
              <th>{t('priority', 'Priority')}</th>
              <th>{t('status', 'Status')}</th>
              <th>{t('lastUpdated', 'Last Updated')}</th>
              <th>{t('actions', 'Actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredRules.map((rule: Rule) => (
              <tr key={rule.id}>
                <td>
                  <div>
                    <div className="font-medium">{rule.name}</div>
                    <div className="text-sm text-gray-500">{rule.description}</div>
                  </div>
                </td>
                <td>
                  <Badge variant={
                    rule.type === 'validation' ? 'default' :
                    rule.type === 'automation' ? 'secondary' :
                    'outline'
                  }>
                    <GitBranch className="h-3 w-3 mr-1" />
                    {rule.type}
                  </Badge>
                </td>
                <td>
                  <Badge variant={
                    rule.priority === 'high' ? 'destructive' :
                    rule.priority === 'medium' ? 'default' :
                    'secondary'
                  }>
                    {rule.priority}
                  </Badge>
                </td>
                <td>
                  <Badge variant={rule.active ? 'default' : 'secondary'}>
                    {rule.active ? t('active', 'Active') : t('inactive', 'Inactive')}
                  </Badge>
                </td>
                <td>{new Date(rule.updated_at).toLocaleDateString()}</td>
                <td>
                  <div className="flex space-x-2">
                    <Button variant="outline" size="sm" onClick={() => openEditModal(rule)}>
                      <Edit className="h-4 w-4" />
                    </Button>
                    <Button variant="outline" size="sm" onClick={() => handleTestRule(rule.id)}>
                      <Play className="h-4 w-4" />
                    </Button>
                    <Button variant="outline" size="sm" onClick={() => handleDeleteRule(rule.id)}>
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
        {filteredRules.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            {t('noRulesFound', 'No rules found')}
          </div>
        )}
      </Card>

      {/* Create/Edit Rule Modal */}
      <Modal open={showCreateForm || !!editingRule} onOpenChange={(open) => {
        if (!open) {
          setShowCreateForm(false)
          setEditingRule(null)
          resetForm()
        }
      }}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>
              <ModalTitle>{editingRule ? t('editRule', 'Edit Rule') : t('createRule', 'Create Rule')}</ModalTitle>
            </ModalHeader>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">{t('name', 'Name')}</label>
                <Input
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder={t('ruleName', 'Rule name')}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">{t('description', 'Description')}</label>
                <Textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder={t('ruleDescription', 'Rule description')}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">{t('type', 'Type')}</label>
                <Select
                  value={formData.type}
                  onValueChange={(value: 'validation' | 'automation' | 'notification') =>
                    setFormData({ ...formData, type: value })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t('selectType', 'Select type')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="validation">{t('validation', 'Validation')}</SelectItem>
                    <SelectItem value="automation">{t('automation', 'Automation')}</SelectItem>
                    <SelectItem value="notification">{t('notification', 'Notification')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">{t('conditions', 'Conditions (JSON)')}</label>
                <Textarea
                  value={formData.conditions}
                  onChange={(e) => setFormData({ ...formData, conditions: e.target.value })}
                  placeholder='[{"field": "status", "operator": "equals", "value": "completed"}]'
                  rows={4}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">{t('actions', 'Actions (JSON)')}</label>
                <Textarea
                  value={formData.actions}
                  onChange={(e) => setFormData({ ...formData, actions: e.target.value })}
                  placeholder='[{"type": "update_field", "field": "priority", "value": "high"}]'
                  rows={4}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">{t('priority', 'Priority')}</label>
                <Select
                  value={formData.priority}
                  onValueChange={(value: 'low' | 'medium' | 'high') =>
                    setFormData({ ...formData, priority: value })
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder={t('selectPriority', 'Select priority')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="low">{t('low', 'Low')}</SelectItem>
                    <SelectItem value="medium">{t('medium', 'Medium')}</SelectItem>
                    <SelectItem value="high">{t('high', 'High')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  id="active"
                  checked={formData.active}
                  onChange={(e) => setFormData({ ...formData, active: e.target.checked })}
                />
                <label htmlFor="active" className="text-sm">{t('active', 'Active')}</label>
              </div>
              <ModalFooter>
                <Button
                  variant="outline"
                  onClick={() => {
                    setShowCreateForm(false)
                    setEditingRule(null)
                    resetForm()
                  }}
                >
                  {t('cancel', 'Cancel')}
                </Button>
                <Button
                  onClick={editingRule ? handleUpdateRule : handleCreateRule}
                  disabled={createRule.loading || updateRule.loading}
                >
                  {createRule.loading || updateRule.loading ? (
                    <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  ) : null}
                  {editingRule ? t('update', 'Update') : t('create', 'Create')}
                </Button>
              </ModalFooter>
            </div>
          </ModalContent>
        </ModalPortal>
      </Modal>

      {/* Test Rule Modal */}
      <Modal open={showTestModal} onOpenChange={setShowTestModal}>
        <ModalPortal>
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>
              <ModalTitle>{t('testRule', 'Test Rule')}</ModalTitle>
            </ModalHeader>
            <div className="space-y-4">
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
              <ModalFooter>
                <Button onClick={() => setShowTestModal(false)}>
                  {t('close', 'Close')}
                </Button>
              </ModalFooter>
            </div>
          </ModalContent>
        </ModalPortal>
      </Modal>
    </div>
  )
}
