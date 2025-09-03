'use client'

import { Suspense } from 'react'
import LazyLoad from '@/components/LazyLoad'

function FeatureCard({ title, description, icon }: { title: string; description: string; icon: string }) {
  return (
    <div className="group rounded-lg border border-transparent px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 hover:dark:border-neutral-700 hover:dark:bg-neutral-800/30">
      <h2 className="mb-3 text-2xl font-semibold">
        {title}{' '}
        <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
          {icon}
        </span>
      </h2>
      <p className="m-0 max-w-[30ch] text-sm opacity-50">
        {description}
      </p>
    </div>
  )
}

function FeaturesSection() {
  return (
    <div className="mb-32 grid text-center lg:max-w-5xl lg:w-full lg:mb-0 lg:grid-cols-4 lg:text-left">
      <LazyLoad>
        <FeatureCard
          title="Projects"
          description="Manage your projects with ease."
          icon="📁"
        />
      </LazyLoad>

      <LazyLoad>
        <FeatureCard
          title="Tasks"
          description="Track tasks and progress."
          icon="✅"
        />
      </LazyLoad>

      <LazyLoad>
        <FeatureCard
          title="Resources"
          description="Allocate and manage resources."
          icon="⚙️"
        />
      </LazyLoad>

      <LazyLoad>
        <FeatureCard
          title="GitHub"
          description="Integrate with GitHub for automation."
          icon="🔗"
        />
      </LazyLoad>
    </div>
  )
}

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm lg:flex">
        <p className="fixed left-0 top-0 flex w-full justify-center border-b border-gray-300 bg-gradient-to-b from-zinc-200 pb-6 pt-8 backdrop-blur-2xl dark:border-neutral-800 dark:bg-zinc-800/30 dark:from-inherit lg:static lg:w-auto  lg:rounded-xl lg:border lg:bg-gray-200 lg:p-4 lg:dark:bg-zinc-800/30">
          Welcome to GravityPM
        </p>
      </div>

      <div className="relative flex place-items-center">
        <h1 className="text-4xl font-bold text-center">
          Project Management Software
          <br />
          with GitHub Integration
        </h1>
      </div>

      <Suspense fallback={<div className="animate-pulse bg-gray-200 rounded h-32 mb-32"></div>}>
        <FeaturesSection />
      </Suspense>
    </main>
  )
}
