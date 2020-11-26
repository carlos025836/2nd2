import { expect } from 'chai'
import React from 'react'
import { screen } from '@testing-library/react'
import renderWithContext from '../helpers/render-with-context'

import FileTreeToolbar from '../../../../../frontend/js/features/file-tree/components/file-tree-toolbar'

describe('<FileTreeToolbar/>', function() {
  it('without selected files', function() {
    renderWithContext(<FileTreeToolbar />)

    expect(screen.queryByRole('button', { name: 'New File' })).to.not.exist
    expect(screen.queryByRole('button', { name: 'New Folder' })).to.not.exist
    expect(screen.queryByRole('button', { name: 'Upload' })).to.not.exist
    expect(screen.queryByRole('button', { name: 'Rename' })).to.not.exist
    expect(screen.queryByRole('button', { name: 'Delete' })).to.not.exist
  })

  it('read-only', function() {
    renderWithContext(<FileTreeToolbar />, {
      contextProps: { hasWritePermissions: false }
    })

    expect(screen.queryByRole('button')).to.not.exist
  })

  it('with one selected file', function() {
    renderWithContext(<FileTreeToolbar />, {
      contextProps: { initialSelectedEntityId: '123abc' }
    })

    screen.getByRole('button', { name: 'Rename' })
    screen.getByRole('button', { name: 'Delete' })
  })
})
